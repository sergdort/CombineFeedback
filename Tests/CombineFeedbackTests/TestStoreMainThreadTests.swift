import CombineFeedback
import CombineFeedbackTest
import Foundation
import Testing

// The test store drains only on the main thread. An event from another thread
// waits in the queue for the main queue, so it can never reduce between two
// sends from a `@MainActor` test.
@MainActor
struct TestStoreMainThreadTests {
  @Test func anEventFromAnotherThreadReducesOnTheMainThread() async {
    let reductions = ReductionLog()
    let store = TestStore(initial: [Int](), machine: Machine {
      Reducer<[Int], Int> { state, event in
        reductions.record(onMainThread: Thread.isMainThread)
        state.append(event)
      }
    })

    // The other thread's send returns before the main thread can drain, so
    // its event is only queued.
    let sent = DispatchSemaphore(value: 0)
    let inner = store.store
    Thread {
      inner.send(event: 1)
      sent.signal()
    }.start()
    #expect(waitForSignal(sent), "The other thread never sent its event.")
    #expect(store.state == [])

    // A send on the main thread drains the queue in order before it returns.
    store.send(10)
    store.send(20)
    #expect(store.state == [1, 10, 20])
    #expect(reductions.onMainThread == [true, true, true])
  }

  @Test func waitReturnsAfterTheMainQueueDrainsAnotherThreadsEvent() async {
    let store = TestStore(initial: 0, machine: Machine {
      Reducer<Int, Int> { $0 += $1 }
    })

    let inner = store.store
    Thread { inner.send(event: 1) }.start()
    await store.wait(timeout: 2) { @Sendable in $0 == 1 }

    store.send(10)
    #expect(store.state == 11, "A send on the main thread reduces before it returns.")
  }
}

/// Blocks the caller with a failure deadline. It is synchronous so the
/// semaphore wait does not run on an async context.
private func waitForSignal(_ semaphore: DispatchSemaphore) -> Bool {
  semaphore.wait(timeout: .now() + 2) == .success
}

// Records the thread of each reduction. A production store can reduce on any
// thread, so the log takes a lock.
private final class ReductionLog: @unchecked Sendable {
  private let lock = NSLock()
  private var _onMainThread: [Bool] = []
  var onMainThread: [Bool] {
    lock.lock(); defer { lock.unlock() }
    return _onMainThread
  }

  func record(onMainThread: Bool) {
    lock.lock(); _onMainThread.append(onMainThread); lock.unlock()
  }
}
