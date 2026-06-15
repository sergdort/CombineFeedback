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
        Reduce { (state: inout String, event: String) in
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
        Reduce { (state: inout State, event: Event) in
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
        Reduce { (state: inout State, event: Event) in
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
        Reduce { (state: inout State, event: Event) in
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
        Reduce { (state: inout State, event: Event) in
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
        Reduce { (state: inout State, event: Event) in
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
        Reduce { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, String?>(/Event.setRequest) { request in
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
        Reduce { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, Void>(/Event.noop) {
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

  func test_onState_runs_for_initial_and_every_state_emission() {
    let input = PassthroughSubject<Event, Never>()
    var observed: [String?] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reduce { (state: inout State, event: Event) in
          if case let .setRequest(request) = event {
            state.request = request
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnState<State, Event, String?>(\.request) { request in
          observed.append(request)
          return Empty<Event, Never>()
        }
      }
    )

    cancellable = system.sink { _ in }
    input.send(.setRequest("a"))

    XCTAssertEqual(observed, [nil, "a"])
  }

  func test_middleware_runs_after_reducer_for_real_events_only() {
    let input = PassthroughSubject<Event, Never>()
    var observed: [(String?, Event)] = []

    let system = Publishers.system(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reduce { (state: inout State, event: Event) in
          if case let .setRequest(request) = event {
            state.request = request
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        Middleware<State, Event> { state, event in
          observed.append((state.request, event))
          return Empty<Event, Never>()
        }
      }
    )

    cancellable = system.sink { _ in }
    XCTAssertEqual(observed.count, 0)

    input.send(.setRequest("a"))

    XCTAssertEqual(observed.count, 1)
    XCTAssertEqual(observed.first?.0, "a")
  }

  func test_store_runtime_accepts_complete_machine() {
    let store = Store(
      initial: State(request: nil, values: []),
      machine: Machine<State, Event> {
        Reduce { (state: inout State, event: Event) in
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
          event: /ParentEvent.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reduce { (state: inout ChildState, event: ChildEvent) in
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

  func test_ifLet_ignores_child_events_while_state_is_nil() {
    let input = PassthroughSubject<ParentEvent, Never>()
    var result: [String?] = []

    let system = Publishers.system(
      initial: OptionalParentState(child: ChildState(value: "a")),
      machine: Machine<OptionalParentState, ParentEvent> {
        Reduce { (state: inout OptionalParentState, event: ParentEvent) in
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
          event: /ParentEvent.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reduce { (state: inout ChildState, event: ChildEvent) in
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
        Reduce { (state: inout OptionalParentState, event: ParentEvent) in
          switch event {
          case .child(.removeParent):
            state.child = nil
          case .child, .removeChild, .noop:
            break
          }
        }

        IfLet<OptionalParentState, ParentEvent, Machine<ChildState, ChildEvent>>(
          state: \OptionalParentState.child,
          event: /ParentEvent.child
        ) {
          Machine<ChildState, ChildEvent> {
            Reduce { (state: inout ChildState, event: ChildEvent) in
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
          event: /ParentEvent.child
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
        Reduce { (state: inout State, event: Event) in
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
        Reduce { (state: inout State, event: Event) in
          if case let .response(value) = event {
            state.values.append(value)
          }
        }

        Feedback<State, Event>.custom { _, output in
          input.enqueue(to: output)
        }

        OnEvent<State, Event, String?>(/Event.setRequest) { request in
          EventSequence([.response(request ?? "nil"), .response("done")])
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
}

private struct State: Equatable {
  var request: String?
  var values: [String]
}

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

private struct PendingOutputPublisher<Output>: Publisher {
  typealias Failure = Never

  let outputs: [Output]

  init(_ outputs: [Output]) {
    self.outputs = outputs
  }

  func receive<S>(subscriber: S) where S: Subscriber, Never == S.Failure, Output == S.Input {
    subscriber.receive(subscription: Subscription(outputs: outputs, subscriber: AnySubscriber(subscriber)))
  }

  private final class Subscription: Combine.Subscription {
    private var outputs: [Output]
    private var subscriber: AnySubscriber<Output, Never>?

    init(outputs: [Output], subscriber: AnySubscriber<Output, Never>) {
      self.outputs = outputs
      self.subscriber = subscriber
    }

    func request(_ demand: Subscribers.Demand) {
      guard let subscriber else { return }

      for output in outputs {
        _ = subscriber.receive(output)
      }
      outputs = []
    }

    func cancel() {
      subscriber = nil
      outputs = []
    }
  }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
private struct EventSequence: AsyncSequence, Sendable {
  typealias Element = Event
  typealias Failure = Never

  let events: [Event]

  init(_ events: [Event]) {
    self.events = events
  }

  func makeAsyncIterator() -> Iterator {
    Iterator(events: events)
  }

  struct Iterator: AsyncIteratorProtocol, Sendable {
    private let events: [Event]
    private var index = 0

    init(events: [Event]) {
      self.events = events
    }

    mutating func next() async -> Event? {
      guard index < events.count else { return nil }
      defer { index += 1 }
      return events[index]
    }
  }
}
