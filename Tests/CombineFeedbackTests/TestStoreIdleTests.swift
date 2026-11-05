import CombineFeedback
import CombineFeedbackTest
import Foundation
import IssueReporting
import Testing

// The loop records a state before it runs the feedbacks and releases the
// reducer lock. These tests hold another thread inside a feedback to prove that
// `wait` returns only when the loop is idle.
struct TestStoreIdleTests {
  @Test func waitReturnsOnlyAfterAnotherThreadFinishesItsDrain() async {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    let store = TestStore(initial: 0, machine: Machine {
      Reducer<Int, Int> { $0 += $1 }
      SideEffect<Int, Int>(synchronous: { _, event in
        guard event == 1 else { return }
        entered.signal()
        release.wait()
      })
    })

    Thread { store.send(1) }.start()
    #expect(waitForSignal(entered), "The background send never reached its feedback.")
    #expect(store.state == 1, "The state is published before the feedback runs.")

    let reporter = RecordingReporter()
    await withIssueReporters([reporter]) {
      await store.wait(timeout: 0.05) { $0 == 1 }
    }
    #expect(reporter.messages.count == 1)
    #expect(reporter.messages.first?.contains("never became idle") == true)

    release.signal()
    await store.wait(timeout: 2) { $0 == 1 }

    store.send(10)
    #expect(store.state == 11, "A send after wait reduces before it returns.")
  }

  @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
  @Test func sendBlocksWhileAnotherThreadDrainsTheLoop() async {
    let entered = DispatchSemaphore(value: 0)
    let release = DispatchSemaphore(value: 0)
    // An observation delivers its values on another thread, as production
    // `AsyncSequence` sources do.
    let (values, observation) = AsyncStream.makeStream(of: Int.self)
    let store = TestStore(initial: 0, machine: Machine {
      Reducer<Int, Int> { $0 += $1 }
      OnStoreStart<Int, Int, AsyncStream<Int>> { values }
      SideEffect<Int, Int>(synchronous: { _, event in
        guard event == 1 else { return }
        entered.signal()
        release.wait()
      })
    })

    observation.yield(1)
    #expect(waitForSignal(entered), "The observed value never reached its feedback.")

    // The observation's thread holds the reducer lock, so this send can only
    // queue its event. It blocks until its timeout and then reports.
    let reporter = RecordingReporter()
    withIssueReporters([reporter]) {
      store.send(10, timeout: 0.05)
    }
    #expect(reporter.messages.count == 1)
    #expect(reporter.messages.first?.contains("still busy") == true)
    #expect(store.state == 1, "The queued event waits for the background drain.")

    // The background thread drains the queued event when it is released.
    release.signal()
    await store.wait(timeout: 2) { $0 == 11 }
  }
}

/// Blocks the caller with a failure deadline. It is synchronous so the
/// semaphore wait does not run on an async context.
private func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
  semaphore.wait(timeout: .now() + 2) == .success
}

// Captures `wait` timeout reports so the expected timeout does not fail this test.
private final class RecordingReporter: IssueReporter, @unchecked Sendable {
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
