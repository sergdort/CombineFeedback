import Combine
import CombineFeedback
import Foundation
import XCTest

final class OnStoreStartTests: XCTestCase {
  func test_onStoreStart_subscribes_once_for_store_lifetime() async throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    let source = ControlledAsyncSequence<OnStoreStartEvent>()
    let factoryCalls = LockedCounter()
    let (states, stateContinuation) = makeStateStream()
    let system = Publishers.system(
      initial: OnStoreStartState(),
      machine: makeMachine(source: source, factoryCalls: factoryCalls)
    )

    let cancellable = system.sink { stateContinuation.yield($0) }
    await source.waitForIterator()
    var iterator = states.makeAsyncIterator()
    let initialState = await iterator.next()

    XCTAssertEqual(initialState, OnStoreStartState())
    XCTAssertEqual(factoryCalls.value, 1)
    XCTAssertEqual(source.numberOfIterators, 1)

    source.yield(.append("first"))
    let firstState = await iterator.next()
    XCTAssertEqual(firstState, OnStoreStartState(values: ["first"]))

    source.yield(.append("second"))
    let secondState = await iterator.next()
    XCTAssertEqual(secondState, OnStoreStartState(values: ["first", "second"]))
    XCTAssertEqual(factoryCalls.value, 1)
    XCTAssertEqual(source.numberOfIterators, 1)

    cancellable.cancel()
    await source.waitForTermination()
    stateContinuation.finish()
  }

  func test_onStoreStart_forwards_sequence_events() async throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    let source = ControlledAsyncSequence<OnStoreStartEvent>()
    let (states, stateContinuation) = makeStateStream()
    let system = Publishers.system(
      initial: OnStoreStartState(),
      machine: makeMachine(source: source)
    )

    let cancellable = system.sink { stateContinuation.yield($0) }
    await source.waitForIterator()
    var iterator = states.makeAsyncIterator()
    _ = await iterator.next()

    source.yield(.append("forwarded"))
    let forwardedState = await iterator.next()
    XCTAssertEqual(forwardedState, OnStoreStartState(values: ["forwarded"]))

    cancellable.cancel()
    await source.waitForTermination()
    stateContinuation.finish()
  }

  func test_onStoreStart_accepts_raw_asyncStream() async throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    let stream = AsyncStream<OnStoreStartEvent>.makeStream()
    let (states, stateContinuation) = makeStateStream()
    let system = Publishers.system(
      initial: OnStoreStartState(),
      machine: Machine {
        makeReducer(blockControl: nil, reducedValues: nil)
        OnStoreStart<OnStoreStartState, OnStoreStartEvent, AsyncStream<OnStoreStartEvent>> {
          stream.stream
        }
      }
    )

    let cancellable = system.sink { stateContinuation.yield($0) }
    var iterator = states.makeAsyncIterator()
    _ = await iterator.next()

    stream.continuation.yield(.append("raw stream"))
    let stateAfterRawEvent = await iterator.next()
    XCTAssertEqual(stateAfterRawEvent, OnStoreStartState(values: ["raw stream"]))

    stream.continuation.finish()
    cancellable.cancel()
    stateContinuation.finish()
  }

  func test_onStoreStart_does_not_restart_after_finite_sequence_finishes() async throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    let source = ControlledAsyncSequence<OnStoreStartEvent>()
    let input = OnStoreStartInput()
    let factoryCalls = LockedCounter()
    let (states, stateContinuation) = makeStateStream()
    let system = Publishers.system(
      initial: OnStoreStartState(),
      machine: makeMachine(source: source, factoryCalls: factoryCalls, input: input)
    )

    let cancellable = system.sink { stateContinuation.yield($0) }
    await source.waitForIterator()
    var iterator = states.makeAsyncIterator()
    _ = await iterator.next()

    source.yield(.append("finite"))
    source.finish()
    let finiteState = await iterator.next()
    XCTAssertEqual(finiteState, OnStoreStartState(values: ["finite"]))
    await source.waitForTermination()

    // A separate feedback drives a real state event after the sequence ended.
    input.send(.append("after termination"))
    let stateAfterTermination = await iterator.next()
    XCTAssertEqual(
      stateAfterTermination,
      OnStoreStartState(values: ["finite", "after termination"])
    )
    XCTAssertEqual(factoryCalls.value, 1)
    XCTAssertEqual(source.numberOfIterators, 1)

    cancellable.cancel()
    stateContinuation.finish()
  }

  func test_onStoreStart_store_cancellation_drops_queued_events() async throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    let source = ControlledAsyncSequence<OnStoreStartEvent>()
    let input = OnStoreStartInput()
    let blockControl = BlockingControl()
    let reducedValues = LockedArray<String>()
    var store: Store<OnStoreStartState, OnStoreStartEvent>? = Store(
      initial: OnStoreStartState(),
      machine: makeMachine(
        source: source,
        input: input,
        blockControl: blockControl,
        reducedValues: reducedValues
      )
    )

    let cancellable: AnyCancellable
    do {
      let currentStore = try XCTUnwrap(store)
      cancellable = currentStore.publisher.sink { _ in }
    }
    await source.waitForIterator()

    DispatchQueue.global().async {
      input.send(.block)
    }
    blockControl.waitUntilStarted()

    // The first sequence output reaches Floodgate while the reducer lock is
    // held by `.block`, so it is queued and `process` returns. `next()` call 2
    // can only begin after that output has returned to the sequence iterator.
    source.yield(.append("queued"))
    source.yield(.append("also queued"))
    await source.waitForNextCall(2)

    store = nil
    await source.waitForTermination()
    blockControl.unblock()
    blockControl.waitUntilFinished()

    XCTAssertEqual(reducedValues.values, ["block"])
    cancellable.cancel()
  }

  func test_onStoreStart_cancel_after_next_returns_still_terminates_the_sequence() async throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    // Producers such as AsyncStream learn that an observer is gone only when a
    // cancelled task calls next(). This sequence cancels the observing task
    // after next() returns a value, which is the window where cancellation
    // used to end the loop without telling the producer.
    let source = ControlledAsyncSequence<OnStoreStartEvent>()
    let reducedValues = LockedArray<String>()
    let system = Publishers.system(
      initial: OnStoreStartState(),
      machine: Machine {
        makeReducer(blockControl: nil, reducedValues: reducedValues)
        OnStoreStart<
          OnStoreStartState,
          OnStoreStartEvent,
          CancelsObserverAfterEachValue<ControlledAsyncSequence<OnStoreStartEvent>.Sequence>
        > {
          CancelsObserverAfterEachValue(base: source.sequence)
        }
      }
    )

    let cancellable = system.sink { _ in }
    await source.waitForIterator()
    source.yield(.append("after cancel"))

    let terminated = expectation(description: "the source sequence terminates")
    Task {
      await source.waitForTermination()
      terminated.fulfill()
    }
    await fulfillment(of: [terminated], timeout: 2)

    XCTAssertEqual(reducedValues.values, [])
    cancellable.cancel()
  }
}

/// Cancels the task that iterates it after each value it returns, so a test can
/// place cancellation between `next()` and the loop body without timing.
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
private struct CancelsObserverAfterEachValue<Base: AsyncSequence & Sendable>: AsyncSequence, Sendable
where Base.Failure == Never {
  typealias Element = Base.Element
  typealias Failure = Never

  let base: Base

  func makeAsyncIterator() -> Iterator {
    Iterator(base: base.makeAsyncIterator())
  }

  struct Iterator: AsyncIteratorProtocol {
    var base: Base.AsyncIterator

    mutating func next() async -> Element? {
      let value = await base.next(isolation: nil)
      if value != nil {
        withUnsafeCurrentTask { $0?.cancel() }
      }
      return value
    }
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
private func makeMachine(
  source: ControlledAsyncSequence<OnStoreStartEvent>,
  factoryCalls: LockedCounter? = nil,
  input: OnStoreStartInput? = nil,
  blockControl: BlockingControl? = nil,
  reducedValues: LockedArray<String>? = nil
) -> Machine<OnStoreStartState, OnStoreStartEvent> {
  Machine {
    makeReducer(blockControl: blockControl, reducedValues: reducedValues)
    makeInputFeedback(input)
    OnStoreStart<
      OnStoreStartState,
      OnStoreStartEvent,
      ControlledAsyncSequence<OnStoreStartEvent>.Sequence
    > {
      if let factoryCalls {
        _ = factoryCalls.increment()
      }
      return source.sequence
    }
  }
}

private func makeInputFeedback(
  _ input: OnStoreStartInput?
) -> Feedback<OnStoreStartState, OnStoreStartEvent> {
  Feedback.custom { _, output in
    guard let input else {
      return Empty<Never, Never>().eraseToAnyPublisher()
    }
    return input.subject.enqueue(to: output).eraseToAnyPublisher()
  }
}

private func makeReducer(
  blockControl: BlockingControl?,
  reducedValues: LockedArray<String>?
) -> Reducer<OnStoreStartState, OnStoreStartEvent> {
  Reducer { state, event in
    switch event {
    case let .append(value):
      state.values.append(value)
      reducedValues?.append(value)
    case .block:
      blockControl?.block()
      state.values.append("block")
      reducedValues?.append("block")
      blockControl?.markFinished()
    }
  }
}

private func makeStateStream() -> (
  AsyncStream<OnStoreStartState>,
  AsyncStream<OnStoreStartState>.Continuation
) {
  var continuation: AsyncStream<OnStoreStartState>.Continuation!
  let stream = AsyncStream<OnStoreStartState> { continuation = $0 }
  return (stream, continuation)
}

private final class OnStoreStartInput: @unchecked Sendable {
  let subject = PassthroughSubject<OnStoreStartEvent, Never>()

  func send(_ event: OnStoreStartEvent) {
    subject.send(event)
  }
}

private final class BlockingControl: @unchecked Sendable {
  private let started = DispatchSemaphore(value: 0)
  private let release = DispatchSemaphore(value: 0)
  private let finished = DispatchSemaphore(value: 0)

  func block() {
    started.signal()
    release.wait()
  }

  func waitUntilStarted() {
    started.wait()
  }

  func unblock() {
    release.signal()
  }

  func markFinished() {
    finished.signal()
  }

  func waitUntilFinished() {
    finished.wait()
  }
}

private struct OnStoreStartState: Equatable {
  var values: [String] = []
}

private enum OnStoreStartEvent {
  case append(String)
  case block
}
