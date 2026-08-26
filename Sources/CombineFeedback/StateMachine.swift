import CasePaths
import Combine

public protocol StateMachine<State, Event> {
  associatedtype State
  associatedtype Event
  associatedtype Body: StateMachine

  var body: Body { get }

  func _resolve() -> ResolvedMachine<State, Event>
}

public extension StateMachine where Body: StateMachine, Body.State == State, Body.Event == Event {
  func _resolve() -> ResolvedMachine<State, Event> {
    body._resolve()
  }
}

public extension StateMachine where Body == Never {
  var body: Never {
    fatalError("Primitive state machines do not have a body.")
  }
}

extension Never: StateMachine {
  public typealias State = Never
  public typealias Event = Never
  public typealias Body = Never

  public var body: Never { fatalError("Never has no state-machine body.") }

  public func _resolve() -> ResolvedMachine<Never, Never> {
    fatalError("Never cannot be resolved as a state machine.")
  }
}

public struct Machine<State, Event>: StateMachine {
  public typealias Body = Never

  private let resolved: ResolvedMachine<State, Event>

  public init(
    @StateMachineBuilder<State, Event> _ build: () -> Machine<State, Event>
  ) {
    self.resolved = build()._resolve()
  }

  init(resolved: ResolvedMachine<State, Event>) {
    self.resolved = resolved
  }

  public func _resolve() -> ResolvedMachine<State, Event> {
    resolved
  }
}

@resultBuilder
public enum StateMachineBuilder<State, Event> {
  /// Gives every statement in a builder block an immediate contextual type of
  /// `some StateMachine<State, Event>`, which lets unrooted key paths such as
  /// `event: \.child` infer their root from the enclosing machine.
  public static func buildExpression<M: StateMachine>(_ expression: M) -> M where M.State == State, M.Event == Event {
    expression
  }

  public static func buildBlock() -> Machine<State, Event> {
    Machine(resolved: .empty)
  }

  public static func buildBlock<M: StateMachine>(_ machine: M) -> Machine<State, Event> where M.State == State, M.Event == Event {
    Machine(resolved: machine._resolve())
  }

  public static func buildPartialBlock<M: StateMachine>(first: M) -> Machine<State, Event> where M.State == State, M.Event == Event {
    Machine(resolved: first._resolve())
  }

  public static func buildPartialBlock<Accumulated: StateMachine, Next: StateMachine>(
    accumulated: Accumulated,
    next: Next
  ) -> Machine<State, Event>
  where Accumulated.State == State, Accumulated.Event == Event, Next.State == State, Next.Event == Event {
    Machine(resolved: .combine(accumulated._resolve(), next._resolve()))
  }

  public static func buildEither<M: StateMachine>(first component: M) -> Machine<State, Event> where M.State == State, M.Event == Event {
    Machine(resolved: component._resolve())
  }

  public static func buildEither<M: StateMachine>(second component: M) -> Machine<State, Event> where M.State == State, M.Event == Event {
    Machine(resolved: component._resolve())
  }

  public static func buildOptional<M: StateMachine>(_ component: M?) -> Machine<State, Event> where M.State == State, M.Event == Event {
    Machine(resolved: component?._resolve() ?? .empty)
  }
}

public struct ResolvedMachine<State, Event> {
  let reducer: Reducer<State, Event>
  let feedbacks: [Feedback<State, Event>]

  static var empty: ResolvedMachine {
    ResolvedMachine(reducer: Reducer { _, _ in }, feedbacks: [])
  }

  static func combine(_ machines: ResolvedMachine...) -> ResolvedMachine {
    combine(machines)
  }

  static func combine(_ machines: [ResolvedMachine]) -> ResolvedMachine {
    ResolvedMachine(
      reducer: Reducer.combine(machines.map(\.reducer)),
      feedbacks: machines.flatMap(\.feedbacks)
    )
  }
}

public struct Scope<ParentState, ParentEvent, Child: StateMachine>: StateMachine {
  public typealias State = ParentState
  public typealias Event = ParentEvent
  public typealias Body = Never

  private let resolve: () -> ResolvedMachine<ParentState, ParentEvent>

  public init<ChildState, ChildEvent>(
    state: WritableKeyPath<ParentState, ChildState>,
    event: CaseKeyPath<ParentEvent, ChildEvent>,
    @StateMachineBuilder<ChildState, ChildEvent> child: () -> Child
  ) where ParentEvent: CasePathable, ChildState == Child.State, ChildEvent == Child.Event {
    let child = child()
    self.resolve = {
      let resolved = child._resolve()
      return ResolvedMachine(
        reducer: scopedReducer(resolved.reducer, state: state, event: event),
        feedbacks: resolved.feedbacks.map {
          scopedFeedback($0, state: state, event: event)
        }
      )
    }
  }

  public init<ChildState, ChildEvent>(
    state: CaseKeyPath<ParentState, ChildState>,
    event: CaseKeyPath<ParentEvent, ChildEvent>,
    @StateMachineBuilder<ChildState, ChildEvent> child: () -> Child
  ) where ParentState: CasePathable, ParentEvent: CasePathable, ChildState == Child.State, ChildEvent == Child.Event {
    let child = child()
    self.resolve = {
      let resolved = child._resolve()
      return ResolvedMachine(
        reducer: scopedReducer(resolved.reducer, state: state, event: event),
        feedbacks: resolved.feedbacks.map {
          scopedFeedback($0, state: state, event: event)
        }
      )
    }
  }

  public func _resolve() -> ResolvedMachine<ParentState, ParentEvent> {
    resolve()
  }
}

public struct IfLet<ParentState, ParentEvent, Child: StateMachine>: StateMachine
where ParentEvent: CasePathable {
  public typealias State = ParentState
  public typealias Event = ParentEvent
  public typealias Body = Never

  private let stateKeyPath: WritableKeyPath<ParentState, Child.State?>
  private let eventKeyPath: CaseKeyPath<ParentEvent, Child.Event>
  private let child: Child

  public init<ChildState, ChildEvent>(
    state: WritableKeyPath<ParentState, ChildState?>,
    event: CaseKeyPath<ParentEvent, ChildEvent>,
    @StateMachineBuilder<ChildState, ChildEvent> child: () -> Child
  ) where ChildState == Child.State, ChildEvent == Child.Event {
    self.stateKeyPath = state
    self.eventKeyPath = event
    self.child = child()
  }

  public func _resolve() -> ResolvedMachine<ParentState, ParentEvent> {
    let resolved = child._resolve()
    return ResolvedMachine(
      reducer: scopedReducer(resolved.reducer, state: stateKeyPath, event: eventKeyPath),
      feedbacks: resolved.feedbacks.map {
        scopedFeedback($0, state: stateKeyPath, event: eventKeyPath)
      }
    )
  }
}
