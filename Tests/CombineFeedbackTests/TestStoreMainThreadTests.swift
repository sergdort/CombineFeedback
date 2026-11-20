import CasePaths
import Combine
import CombineFeedback
import CombineFeedbackTest
import Foundation
import Testing

// The test store drains only on the main thread. An event from another thread
// waits until the next outer drain on the main thread starts: the next `send`,
// or the main queue at an `await`. A drain that is already running never
// reduces it.
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
    // its event only waits.
    let sent = DispatchSemaphore(value: 0)
    let inner = store.store
    Thread {
      inner.send(event: 1)
      sent.signal()
    }.start()
    #expect(waitForSignal(sent), "The other thread never sent its event.")
    #expect(store.state == [])

    // A send on the main thread reduces the waiting event first, as
    // production would, then its own event.
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

  @Test func anAnswerFromAnotherThreadDoesNotReduceInsideTheSendThatAskedForIt() async {
    let store = TestStore(initial: Loader.State.idle, machine: Loader())

    // The effect hands its answer to the loop while `send` still drains.
    store.send(.load)
    #expect(store.state == .loading)

    await store.wait(timeout: 2) { $0 == .loaded }
  }

  @Test func anAnswerFromAnotherThreadDoesNotReduceInsideInit() async {
    // The first feedback answers from another thread while `init` still
    // drains. The second feedback answers synchronously in the same drain.
    let store = TestStore(initial: Starter.State(), machine: Starter())
    #expect(store.state.log == ["synchronous"])

    await store.wait(timeout: 2) { $0.log == ["synchronous", "background"] }
  }

  @Test func anAnswerThatArrivedBeforeTheNextSendReducesBeforeIt() async {
    let delivered = DispatchSemaphore(value: 0)
    let store = TestStore(initial: Search.State(), machine: Search(delivered: delivered))
    #expect(waitForSignal(delivered), "The first answer never arrived.")

    store.send(.setQuery(1))
    #expect(waitForSignal(delivered), "The second answer never arrived.")
    store.send(.setQuery(2))

    #expect(store.state.log == ["load0 at query0", "set1", "load1 at query1", "set2"])
    await store.wait(timeout: 2) { $0.log.last == "load2 at query2" }
  }
}

// Emits its value from a new thread, and returns from `receive(subscriber:)`
// only after the loop has taken the value. So the value reaches the loop while
// the main thread is still inside the drain that started the effect.
private struct AnswersDuringTheDrain<Output>: Publisher {
  typealias Failure = Never
  let value: Output

  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    subscriber.receive(subscription: Subscriptions.empty)
    let delivered = DispatchSemaphore(value: 0)
    let box = SubscriberBox(subscriber: AnySubscriber(subscriber), value: value)
    Thread {
      _ = box.subscriber.receive(box.value)
      delivered.signal()
    }.start()
    _ = waitForSignal(delivered)
  }
}

// Emits its value from a new thread, then signals `delivered`. It returns from
// `receive(subscriber:)` at once.
private struct AnswersLater<Output>: Publisher {
  typealias Failure = Never
  let value: Output
  let delivered: DispatchSemaphore

  func receive<S: Subscriber>(subscriber: S) where S.Input == Output, S.Failure == Never {
    subscriber.receive(subscription: Subscriptions.empty)
    let box = SubscriberBox(subscriber: AnySubscriber(subscriber), value: value)
    Thread { [delivered] in
      _ = box.subscriber.receive(box.value)
      box.subscriber.receive(completion: .finished)
      delivered.signal()
    }.start()
  }
}

// The test hands the subscriber to one other thread, which alone uses it.
private struct SubscriberBox<Output>: @unchecked Sendable {
  let subscriber: AnySubscriber<Output, Never>
  let value: Output
}

private struct Loader: StateMachine {
  enum State: Equatable { case idle, loading, loaded }
  @CasePathable enum Event { case load, didLoad }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer<State, Event> { state, event in
      switch event {
      case .load: state = .loading
      case .didLoad: state = .loaded
      }
    }
    OnEvent(\.load) { () -> AnswersDuringTheDrain<Event> in
      AnswersDuringTheDrain(value: .didLoad)
    }
  }
}

private struct Starter: StateMachine {
  struct State: Equatable {
    var a = 0
    var b = 0
    var log: [String] = []
  }

  @CasePathable enum Event { case background, synchronous }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer<State, Event> { state, event in
      switch event {
      case .background: state.log.append("background")
      case .synchronous: state.log.append("synchronous")
      }
    }
    OnChange(of: \.a) { (_: Int) -> AnswersDuringTheDrain<Event> in
      AnswersDuringTheDrain(value: .background)
    }
    OnChange(of: \.b) { (_: Int) -> Just<Event> in Just(.synchronous) }
  }
}

private struct Search: StateMachine {
  struct State: Equatable {
    var query = 0
    var log: [String] = []
  }

  @CasePathable enum Event { case setQuery(Int), didLoad(Int) }
  let delivered: DispatchSemaphore

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer<State, Event> { state, event in
      switch event {
      case let .setQuery(query):
        state.query = query
        state.log.append("set\(query)")
      case let .didLoad(query):
        state.log.append("load\(query) at query\(state.query)")
      }
    }
    OnChange(of: \.query) { [delivered] (query: Int) -> AnswersLater<Event> in
      AnswersLater(value: .didLoad(query), delivered: delivered)
    }
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
