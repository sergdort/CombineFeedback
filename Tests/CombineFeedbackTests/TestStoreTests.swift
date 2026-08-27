import Combine
import CombineFeedback
import CombineFeedbackTest
import IssueReporting
import Foundation
import XCTest

// A fetch + pagination + retry machine mirroring the Example `Movies` machine,
// inlined so these tests run under `swift test` without the Xcode app target.
private struct Fetcher: StateMachine {
  let fetch: (Int) async throws -> [Int]

  struct State: Equatable {
    var items: [Int] = []
    var page: Int = 0
    var status: Status = .idle

    enum Status: Equatable {
      case idle
      case loading
      case failed(String)
    }

    // The fetch feedback is driven entirely off this derived value.
    var nextPage: Int? {
      status == .loading ? page + 1 : nil
    }
  }

  enum Event {
    case fetchNext
    case retry
    case didLoad([Int])
    case didFail(String)
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    reducer
    feedback
  }

  var reducer: Reducer<State, Event> {
    Reducer { state, event in
      switch event {
      case .fetchNext:
        state.status = .loading
      case .retry:
        state.status = .loading
      case let .didLoad(items):
        state.items += items
        state.page += 1
        state.status = .idle
      case let .didFail(message):
        state.status = .failed(message)
      }
    }
  }

  var feedback: OnChange<State, Event, Int> {
    OnChange(of: \.nextPage) { page async in
      do {
        return .didLoad(try await fetch(page))
      } catch {
        return .didFail("\(error)")
      }
    }
  }
}

final class TestStoreTests: XCTestCase {
  // With an immediate mock, the loop reaches `.idle` with data essentially
  // instantly, well under the default 100ms budget.
  func test_fetchNext_reaches_loaded() async throws {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { page in [page * 10, page * 10 + 1] })
    )

    store.send(.fetchNext)
    await store.wait { $0.status == .idle && !$0.items.isEmpty }

    XCTAssertEqual(store.state.items, [10, 11])
    XCTAssertEqual(store.state.page, 1)
  }

  // Ordered key-waypoints (style 3) fall out of sequential `wait`s — no new API.
  func test_pagination_two_pages_in_order() async throws {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { page in [page * 10] })
    )

    store.send(.fetchNext)
    await store.wait { $0.status == .idle && $0.items == [10] }

    store.send(.fetchNext)
    await store.wait { $0.status == .idle && $0.items == [10, 20] }

    XCTAssertEqual(store.state.page, 2)
  }

  // A transient waypoint (`.loading`) the loop has already left behind is still
  // observable, because `wait` consumes the recorded trajectory in order rather
  // than polling the instantaneous state. This settles the loop to `.idle`
  // *before* the first `wait`, so `.loading` is provably gone from the current
  // state — the pre-fix polling implementation timed out here.
  func test_wait_observes_a_transient_waypoint_after_the_loop_settled() async {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { page in [page * 10] })
    )

    store.send(.fetchNext)

    // Spin (not via `wait`) until the loop is back at `.idle` with data.
    while !(store.state.status == .idle && !store.state.items.isEmpty) {
      await Task.yield()
    }

    let reporter = RecordingIssueReporter()
    await withIssueReporters([reporter]) {
      await store.wait { $0.status == .loading }                       // the spinner...
      await store.wait { $0.status == .idle && $0.items == [10] }      // ...then data
    }

    XCTAssertEqual(reporter.messages, [], reporter.messages.first ?? "")
  }

  // The trajectory cursor must not manufacture false positives: a predicate no
  // recorded state satisfies still times out.
  func test_wait_times_out_for_a_state_never_reached() async {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { page in [page * 10] })
    )

    store.send(.fetchNext)

    let reporter = RecordingIssueReporter()
    await withIssueReporters([reporter]) {
      await store.wait(timeout: 0.05) { $0.items.count == 99 }
    }

    XCTAssertEqual(reporter.messages.count, 1)
  }

  // Retry after a failure: the destination is what matters, not the path.
  func test_retry_after_failure_reaches_loaded() async throws {
    let shouldFail = LockedFlag(true)
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { page in
        if shouldFail.swap(false) {
          throw NSError(domain: "test", code: 1)
        }
        return [page * 10]
      })
    )

    store.send(.fetchNext)
    await store.wait { if case .failed = $0.status { return true } else { return false } }

    store.send(.retry)
    await store.wait { $0.status == .idle && $0.items == [10] }
  }

  // Prove the diagnostic: a predicate that never holds times out with a
  // trajectory the developer can actually read.
  func test_timeout_reports_trajectory() async {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { _ in [1] })
    )

    store.send(.fetchNext)
    // The predicate never holds, so wait reports a test issue once the timeout
    // elapses. A custom reporter captures it instead of failing this test.
    let reporter = RecordingIssueReporter()
    await withIssueReporters([reporter]) {
      await store.wait(timeout: 0.05) { $0.items.count == 99 }
    }

    XCTAssertEqual(reporter.messages.count, 1)
    let message = reporter.messages.first ?? ""
    XCTAssertTrue(message.contains("timed out"), message)
    // The recorded trajectory should show the loaded state with items [1].
    XCTAssertTrue(message.contains("Observed trajectory"), message)
    XCTAssertTrue(message.contains("1"), message)
  }
}

private final class RecordingIssueReporter: IssueReporter, @unchecked Sendable {
  private let lock = NSLock()
  private var _messages: [String] = []
  var messages: [String] {
    lock.lock(); defer { lock.unlock() }
    return _messages
  }

  func reportIssue(
    _ message: @autoclosure () -> String?,
    severity: IssueSeverity,
    fileID: StaticString,
    filePath: StaticString,
    line: UInt,
    column: UInt
  ) {
    let captured = message() ?? ""
    lock.lock(); _messages.append(captured); lock.unlock()
  }
}

private final class LockedFlag: @unchecked Sendable {
  private let lock = NSLock()
  private var value: Bool
  init(_ value: Bool) { self.value = value }
  /// Returns the current value and stores `next`.
  func swap(_ next: Bool) -> Bool {
    lock.lock(); defer { lock.unlock() }
    let old = value
    value = next
    return old
  }
}
