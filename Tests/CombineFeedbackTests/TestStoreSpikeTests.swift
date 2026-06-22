import Combine
import CombineFeedback
import CombineFeedbackTest
import Foundation
import XCTest

// A fetch + pagination + retry machine mirroring the Example `Movies` machine,
// inlined so the spike runs under `swift test` without the Xcode app target.
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

final class TestStoreSpikeTests: XCTestCase {
  // Guess #2: with an immediate mock, the loop reaches `.idle` with data
  // essentially instantly, well under the default 100ms budget.
  func test_fetchNext_reaches_loaded() async throws {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { page in [page * 10, page * 10 + 1] })
    )

    store.send(.fetchNext)
    try await store.wait { $0.status == .idle && !$0.items.isEmpty }

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
    try await store.wait { $0.status == .idle && $0.items == [10] }

    store.send(.fetchNext)
    try await store.wait { $0.status == .idle && $0.items == [10, 20] }

    XCTAssertEqual(store.state.page, 2)
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
    try await store.wait { if case .failed = $0.status { return true } else { return false } }

    store.send(.retry)
    try await store.wait { $0.status == .idle && $0.items == [10] }
  }

  // Prove the diagnostic: a predicate that never holds times out with a
  // trajectory the developer can actually read.
  func test_timeout_reports_trajectory() async throws {
    let store = TestStore(
      initial: Fetcher.State(),
      machine: Fetcher(fetch: { _ in [1] })
    )

    store.send(.fetchNext)
    do {
      try await store.wait(timeout: 0.05) { $0.items.count == 99 } // never true
      XCTFail("expected a timeout")
    } catch let error as WaitTimeout<Fetcher.State> {
      // The message should show idle -> loading -> idle(items:[1]).
      XCTAssertTrue(error.trajectory.contains { $0.items == [1] })
      print(error.description)
    }
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
