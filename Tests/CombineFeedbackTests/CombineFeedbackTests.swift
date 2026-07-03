import CasePaths
import Combine
@testable import CombineFeedback
import XCTest

final class CombineFeedbackTests: XCTestCase {
  private var cancellable: Cancellable!
  private var bag: Set<AnyCancellable> = []

  override func tearDown() {
    cancellable?.cancel()
    cancellable = nil
    bag = []
    super.tearDown()
  }

  func test_emits_initial() {
    var result = [String]()

    let system = Publishers.system(
      initial: "initial",
      machine: Machine<String, String> {
        Reducer { (state: inout String, event: String) in
          state = state + event
        }
      }
    )

    cancellable = system.sink {
      result.append($0)
    }

    XCTAssertEqual(result, ["initial"])
  }

  func test_onChange_fires_for_initial_projected_value() {
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: "a", values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          switch event {
          case let .response(value):
            state.values.append(value)
          case let .setRequest(request):
            state.request = request
          case .noop:
            break
          }
        }

        OnChange<State, Event, String>(of: \.request) { request in
          Just(Event.response(request))
        }
      }
    )

    cancellable = system.output(in: 0...1).sink { state in
      result = state.values
    }

    XCTAssertEqual(result, ["a"])
  }

  func test_onChange_skips_repeated_projected_values() {
    let input = PassthroughSubject<Event, Never>()
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: "a", values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          switch event {
          case let .response(value): state.values.append(value)
          case let .setRequest(request): state.request = request
          case .noop: break
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnChange<State, Event, String>(of: \.request) { request in
          Just(Event.response(request))
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
    }

    input.send(.setRequest("a"))
    input.send(.setRequest("b"))

    XCTAssertEqual(result, ["a", "b"])
  }

  func test_onChange_cancels_queued_events_from_previous_value() {
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: "a", values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          switch event {
          case let .setRequest(request): state.request = request
          case let .response(value): state.values.append(value)
          case .noop: break
          }
        }

        OnChange<State, Event, String>(of: \.request) { request in
          request == "a"
            ? PendingOutputPublisher([Event.setRequest("b"), .response("stale")])
            : PendingOutputPublisher([])
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
    }

    XCTAssertEqual(result, [])
  }

  func test_optional_onChange_suppresses_nil() {
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          switch event {
          case let .response(value): state.values.append(value)
          case let .setRequest(request): state.request = request
          case .noop: break
          }
        }

        OnChange<State, Event, String>(of: \.request) { request in
          Just(Event.response(request))
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
    }

    XCTAssertEqual(result, [])
  }

  func test_optional_onChange_cancels_active_work_when_projection_becomes_nil() {
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: "a", values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          switch event {
          case let .setRequest(request): state.request = request
          case let .response(value): state.values.append(value)
          case .noop: break
          }
        }

        OnChange<State, Event, String>(of: \.request) { _ in
          PendingOutputPublisher([Event.setRequest(nil), .response("stale")])
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
    }

    XCTAssertEqual(result, [])
  }

  func test_onEvent_matches_case_path_payload() {
    let input = PassthroughSubject<Event, Never>()
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, String?>(\.setRequest) { request in
          Just(Event.response(request ?? "nil"))
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
    }

    input.send(.noop)
    input.send(.setRequest("a"))

    XCTAssertEqual(result, ["a"])
  }

  func test_onEvent_no_payload_convenience_matches_void_case_path() {
    let input = PassthroughSubject<Event, Never>()
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, Void>(\.noop) {
          Just(Event.response("retried"))
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
    }
    input.send(.noop)

    XCTAssertEqual(result, ["retried"])
  }

  func test_onEvent_non_matching_events_do_not_cancel_in_flight_work() {
    let input = PassthroughSubject<Event, Never>()
    let effect = ManualPublisher<Event>()

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, String?>(\.setRequest) { _ in
          effect
        }
      }
    )

    cancellable = system.sink { _ in }
    input.send(.setRequest("a"))
    input.send(.noop)

    XCTAssertEqual(effect.cancelCount, 0)

    input.send(.setRequest("b"))

    XCTAssertEqual(effect.cancelCount, 1)
  }

  func test_onEvent_latest_wins_is_scoped_to_each_lane() {
    let input = PassthroughSubject<Event, Never>()
    let firstLane = ManualPublisher<Event>()
    let secondLane = ManualPublisher<Event>()

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, String?>(\.setRequest) { _ in
          firstLane
        }

        OnEvent<State, Event, String?>(\.setRequest) { _ in
          secondLane
        }
      }
    )

    cancellable = system.sink { _ in }
    input.send(.setRequest("a"))

    XCTAssertEqual(firstLane.cancelCount, 0)
    XCTAssertEqual(secondLane.cancelCount, 0)

    input.send(.setRequest("b"))

    XCTAssertEqual(firstLane.cancelCount, 1)
    XCTAssertEqual(secondLane.cancelCount, 1)
  }

  func test_every_accepted_event_emits_state_even_when_unchanged() {
    let input = PassthroughSubject<Event, Never>()
    var observed: [State] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }
      }
    )

    cancellable = system.sink { observed.append($0) }
    input.send(.noop)

    XCTAssertEqual(observed, [State(request: nil, values: []), State(request: nil, values: [])])
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  func test_sideEffect_runs_after_reducer_for_real_events_only() {
    let input = PassthroughSubject<Event, Never>()
    let expectation = expectation(description: "side effect observes event")
    let observed = LockedArray<(String?, Event)>()

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          if case let .setRequest(request) = event {
            state.request = request
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        SideEffect<State, Event> { state, event in
          observed.append((state.request, event))
          expectation.fulfill()
        }
      }
    )

    cancellable = system.sink { _ in }
    input.send(.setRequest("a"))

    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(observed.values.count, 1)
    XCTAssertEqual(observed.values.first?.0, "a")
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  func test_sideEffect_does_not_cancel_previous_event_work() {
    let input = PassthroughSubject<Event, Never>()
    let firstStarted = expectation(description: "first side effect started")
    let secondStarted = expectation(description: "second side effect started")
    let release = AsyncGate()
    let counter = LockedCounter()

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        SideEffect<State, Event> { _, _ in
          let count = counter.increment()
          if count == 1 { firstStarted.fulfill() }
          if count == 2 { secondStarted.fulfill() }
          await release.wait()
        }
      }
    )

    cancellable = system.sink { _ in }
    input.send(.noop)
    input.send(.noop)

    wait(for: [firstStarted, secondStarted], timeout: 1)
    XCTAssertEqual(counter.value, 2)
    Task { await release.open() }
  }

  func test_store_runtime_accepts_complete_machine() {
    let store = Store(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          if case let .setRequest(request) = event {
            state.request = request
          }
        }
      }
    )

    store.send(event: Event.setRequest("a"))

    XCTAssertEqual(store.state.request, "a")
  }

  func test_scope_composes_child_reducer_and_feedback() {
    var result: [String] = []

    let system = Publishers.system(
      initial: ParentState(child: ChildState(value: "a")),
      machine: Machine<ParentState, ParentEvent> {
        Scope<ParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \ParentState.child,
          event: \.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reducer { (state: inout ChildState, event: ChildEvent) in
              if case let .set(value) = event {
                state.value = value
              }
            }

            OnChange<ChildState, ChildEvent, String>(of: \.value) { value in
              Just(ChildEvent.set(value + "!"))
            }
          }
        }
      }
    )

    cancellable = system.output(in: 0...1).sink { state in
      result.append(state.child.value)
    }

    XCTAssertEqual(result, ["a", "a!"])
  }

  func test_scope_composes_case_path_child_reducer_and_feedback() {
    var result: [String?] = []

    let system = Publishers.system(
      initial: SwitchParentState.child(ChildState(value: "a")),
      machine: Machine<SwitchParentState, ParentEvent> {
        Scope<SwitchParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \.child,
          event: \.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reducer { (state: inout ChildState, event: ChildEvent) in
              if case let .set(value) = event {
                state.value = value
              }
            }

            OnChange<ChildState, ChildEvent, String>(of: \.value) { value in
              Just(ChildEvent.set(value + "!"))
            }
          }
        }
      }
    )

    cancellable = system.output(in: 0...1).sink { state in
      result.append(state[case: \.child]?.value)
    }

    XCTAssertEqual(result, ["a", "a!"])
  }

  func test_case_path_scope_cancels_queued_child_output_when_parent_leaves_case() {
    var result: [String?] = []

    let system = Publishers.system(
      initial: SwitchParentState.child(ChildState(value: "a")),
      machine: Machine<SwitchParentState, ParentEvent> {
        Scope<SwitchParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \.child,
          event: \.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reducer { (state: inout ChildState, event: ChildEvent) in
              if case let .set(value) = event {
                state.value = value
              }
            }

            OnChange<ChildState, ChildEvent, String>(of: \.value) { _ in
              PendingOutputPublisher([ChildEvent.removeParent, .set("stale")])
            }
          }
        }

        Reducer { (state: inout SwitchParentState, event: ParentEvent) in
          if case .child(.removeParent) = event {
            state = .other
          }
        }
      }
    )

    cancellable = system.sink { state in
      result.append(state[case: \.child]?.value)
    }

    XCTAssertEqual(result, ["a", nil])
  }

  func test_ifLet_ignores_child_events_while_state_is_nil() {
    let input = PassthroughSubject<ParentEvent, Never>()
    var result: [String?] = []

    let system = Publishers.system(
      initial: OptionalParentState(child: ChildState(value: "a")),
      machine: Machine<OptionalParentState, ParentEvent> {
        Reducer { (state: inout OptionalParentState, event: ParentEvent) in
          switch event {
          case .removeChild:
            state.child = nil
          case .child, .noop:
            break
          }
        }

        Feedback<OptionalParentState, ParentEvent>.custom { _, output in
          input.enqueue(to: output)
        }

        IfLet<OptionalParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \OptionalParentState.child,
          event: \.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reducer { (state: inout ChildState, event: ChildEvent) in
              if case let .set(value) = event {
                state.value = value
              }
            }
          }
        }
      }
    )

    cancellable = system.sink { state in
      result.append(state.child?.value)
    }

    input.send(.removeChild)
    input.send(.child(.set("b")))

    XCTAssertEqual(result, ["a", nil, nil])
    XCTAssertFalse(result.contains("b"))
  }

  func test_ifLet_cancels_queued_child_output_when_child_state_becomes_nil() {
    var result: [String?] = []

    let system = Publishers.system(
      initial: OptionalParentState(child: ChildState(value: "a")),
      machine: Machine<OptionalParentState, ParentEvent> {
        Reducer { (state: inout OptionalParentState, event: ParentEvent) in
          switch event {
          case .child(.removeParent):
            state.child = nil
          case .child, .removeChild, .noop:
            break
          }
        }

        IfLet<OptionalParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \OptionalParentState.child,
          event: \.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reducer { (state: inout ChildState, event: ChildEvent) in
              if case let .set(value) = event {
                state.value = value
              }
            }

            OnChange<ChildState, ChildEvent, String>(of: \.value) { _ in
              PendingOutputPublisher([ChildEvent.removeParent, .set("stale")])
            }
          }
        }
      }
    )

    cancellable = system.sink { state in
      result.append(state.child?.value)
    }

    XCTAssertEqual(result, ["a", nil])
  }

  func test_ifLet_keeps_child_feedback_alive_across_parent_events() {
    let input = PassthroughSubject<ParentEvent, Never>()
    var starts = 0

    let system = Publishers.system(
      initial: OptionalParentState(child: ChildState(value: "a")),
      machine: Machine<OptionalParentState, ParentEvent> {
        Feedback<OptionalParentState, ParentEvent>.custom { _, output in
          input.enqueue(to: output)
        }

        IfLet<OptionalParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \OptionalParentState.child,
          event: \.child
        ) {
          Machine<ChildState, ChildEvent> {
            Feedback<ChildState, ChildEvent>.custom { _, _ in
              starts += 1
              return Empty<Never, Never>()
            }
          }
        }
      }
    )

    cancellable = system.sink { _ in }
    input.send(.noop)
    input.send(.noop)

    XCTAssertEqual(starts, 1)
  }

  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  func test_onChange_async_effect_emits_event() {
    let expectation = expectation(description: "async OnChange emits")
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: "a", values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        OnChange<State, Event, String>(of: \.request) { request async in
          Event.response(request)
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
      if result == ["a"] {
        expectation.fulfill()
      }
    }

    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(result, ["a"])
  }

  func test_onEvent_asyncSequence_effect_emits_events() throws {
    guard #available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *) else {
      throw XCTSkip("Typed AsyncSequence.Failure is unavailable on this OS")
    }

    let input = PassthroughSubject<Event, Never>()
    let expectation = expectation(description: "async sequence OnEvent emits")
    var result: [String] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reducer { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, String?>(\.setRequest) { request in
          ArrayAsyncSequence([.response(request ?? "nil"), .response("done")])
        }
      }
    )

    cancellable = system.sink { state in
      result = state.values
      if result == ["a", "done"] {
        expectation.fulfill()
      }
    }
    input.send(.setRequest("a"))

    wait(for: [expectation], timeout: 1)
    XCTAssertEqual(result, ["a", "done"])
  }

  @MainActor
  func test_storeBinding_exposesInitialState() {
    let store = Store<BindingTestState, BindingTestEvent>(
      initial: BindingTestState(count: 0, text: ""),
      machine: BindingTestMachine()
    )

    let binding = StoreBinding<BindingTestState, BindingTestEvent>(store)

    XCTAssertEqual(binding.wrappedValue, BindingTestState(count: 0, text: ""))
  }

  @MainActor
  func test_storeBinding_sendsEventsThroughStore() {
    let store = Store<BindingTestState, BindingTestEvent>(
      initial: BindingTestState(count: 0, text: ""),
      machine: BindingTestMachine()
    )

    let binding = StoreBinding<BindingTestState, BindingTestEvent>(store)
    binding.projectedValue.send(.increment)

    XCTAssertEqual(store.state.count, 1)
  }

  @MainActor
  func test_storeBinding_keyPathBindingSendsMappedEvent() {
    let store = Store<BindingTestState, BindingTestEvent>(
      initial: BindingTestState(count: 0, text: ""),
      machine: BindingTestMachine()
    )

    let binding = StoreBinding<BindingTestState, BindingTestEvent>(store)
    binding.projectedValue.binding(for: \.text, event: BindingTestEvent.setText).wrappedValue = "hello"

    XCTAssertEqual(store.state.text, "hello")
  }

  @MainActor
  func test_storeBinding_constantEventBindingSendsEvent() {
    let store = Store<BindingTestState, BindingTestEvent>(
      initial: BindingTestState(count: 0, text: ""),
      machine: BindingTestMachine()
    )

    let binding = StoreBinding<BindingTestState, BindingTestEvent>(store)
    binding.projectedValue.binding(for: \.text, event: BindingTestEvent.increment).wrappedValue = "ignored"

    XCTAssertEqual(store.state.count, 1)
    XCTAssertEqual(store.state.text, "")
  }

  // `TaskSubscription.start()` runs after the subscriber receives the
  // subscription, so a synchronous cancel (or a concurrent cancel from a
  // re-subscribing operator) can land before `start()`. A cancelled subscriber
  // must not receive a value: downstream of `enqueue(to:)` that value would
  // re-enter the loop as a stale, already-flushed effect output.
  @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
  func test_taskPublisher_does_not_deliver_after_synchronous_cancel() async {
    let received = LockedArray<Int>()
    let settled = expectation(description: "publisher settled")
    settled.assertForOverFulfill = false

    TaskPublisher { 42 }.receive(
      subscriber: CancelImmediatelySubscriber<Int>(
        onValue: { received.append($0) },
        onSettled: { settled.fulfill() }
      )
    )

    await fulfillment(of: [settled], timeout: 1)

    XCTAssertEqual(
      received.values, [],
      "a subscriber that cancelled before start() must not receive values"
    )
  }
}

/// A subscriber that cancels the moment it receives its subscription, used to
/// prove a cancelled `TaskPublisher` never delivers.
private final class CancelImmediatelySubscriber<Input>: Subscriber, @unchecked Sendable {
  typealias Failure = Never

  private let onValue: @Sendable (Input) -> Void
  private let onSettled: @Sendable () -> Void

  init(onValue: @escaping @Sendable (Input) -> Void, onSettled: @escaping @Sendable () -> Void) {
    self.onValue = onValue
    self.onSettled = onSettled
  }

  func receive(subscription: Subscription) {
    subscription.cancel()
    // Give the task time to run and attempt delivery before the test asserts.
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [onSettled] in
      onSettled()
    }
  }

  func receive(_ input: Input) -> Subscribers.Demand {
    onValue(input)
    return .none
  }

  func receive(completion: Subscribers.Completion<Never>) {}
}

private struct BindingTestState: Equatable, Sendable {
  var count: Int
  var text: String
}

private enum BindingTestEvent: Sendable {
  case increment
  case setText(String)
}

private struct BindingTestMachine: StateMachine {
  typealias State = BindingTestState
  typealias Event = BindingTestEvent

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer { (state: inout BindingTestState, event: BindingTestEvent) in
      switch event {
      case .increment:
        state.count += 1
      case let .setText(text):
        state.text = text
      }
    }
  }
}

private struct State: Equatable {
  var request: String?
  var values: [String]
}

@CasePathable
private enum Event: Equatable, Sendable {
  case setRequest(String?)
  case response(String)
  case noop
}

private struct ParentState: Equatable {
  var child: ChildState
}

private struct OptionalParentState: Equatable {
  var child: ChildState?
}

@CasePathable
private enum SwitchParentState: Equatable {
  case child(ChildState)
  case other
}

@CasePathable
private enum ParentEvent: Equatable, Sendable {
  case child(ChildEvent)
  case removeChild
  case noop
}

private struct ChildState: Equatable {
  var value: String
}

private enum ChildEvent: Equatable, Sendable {
  case set(String)
  case removeParent
}
