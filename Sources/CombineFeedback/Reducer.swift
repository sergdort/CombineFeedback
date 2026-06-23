import CasePaths

public struct Reducer<State, Event> {
  public let reduce: (inout State, Event) -> Void

  public init(reduce: @escaping (inout State, Event) -> Void) {
    self.reduce = reduce
  }

  public func callAsFunction(_ state: inout State, _ event: Event) {
    self.reduce(&state, event)
  }

  public static func combine(_ reducers: Reducer...) -> Reducer {
    combine(reducers)
  }

  public static func combine(_ reducers: [Reducer]) -> Reducer {
    return .init { state, event in
      for reducer in reducers {
        reducer(&state, event)
      }
    }
  }

  public func logging(
    printer: @escaping (String) -> Void = { print($0) }
  ) -> Reducer {
    return .init { state, event in
      self(&state, event)
      printer("Action: \(event)")
      printer("Value:")
      var dumpedNewValue = ""
      dump(state, to: &dumpedNewValue)
      printer(dumpedNewValue)
      printer("---")
    }
  }
}

func scopedReducer<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ reducer: Reducer<ChildState, ChildEvent>,
  state stateKeyPath: WritableKeyPath<ParentState, ChildState>,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Reducer<ParentState, ParentEvent> where ParentEvent: CasePathable {
  Reducer<ParentState, ParentEvent> { parentState, parentEvent in
    guard let childEvent = parentEvent[case: eventKeyPath] else { return }
    reducer(&parentState[keyPath: stateKeyPath], childEvent)
  }
}

func scopedReducer<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ reducer: Reducer<ChildState, ChildEvent>,
  state stateKeyPath: CaseKeyPath<ParentState, ChildState>,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Reducer<ParentState, ParentEvent> where ParentState: CasePathable, ParentEvent: CasePathable {
  Reducer<ParentState, ParentEvent> { parentState, parentEvent in
    guard let childEvent = parentEvent[case: eventKeyPath] else { return }
    guard var childState = parentState[case: stateKeyPath] else { return }
    reducer(&childState, childEvent)
    parentState = stateKeyPath(childState)
  }
}

func scopedReducer<ParentState, ParentEvent, ChildState, ChildEvent>(
  _ reducer: Reducer<ChildState, ChildEvent>,
  state stateKeyPath: WritableKeyPath<ParentState, ChildState?>,
  event eventKeyPath: CaseKeyPath<ParentEvent, ChildEvent>
) -> Reducer<ParentState, ParentEvent> where ParentEvent: CasePathable {
  Reducer<ParentState, ParentEvent> { parentState, parentEvent in
    guard let childEvent = parentEvent[case: eventKeyPath] else { return }
    guard var childState = parentState[keyPath: stateKeyPath] else { return }
    reducer(&childState, childEvent)
    parentState[keyPath: stateKeyPath] = childState
  }
}

extension Reducer: StateMachine {
  public typealias Body = Never

  public func _resolve() -> ResolvedMachine<State, Event> {
    ResolvedMachine(reducer: self, feedbacks: [])
  }
}
