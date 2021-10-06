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
    return .init { state, event in
      for reducer in reducers {
        reducer(&state, event)
      }
    }
  }

  public func pullback<GlobalState, GlobalEvent>(
    value: WritableKeyPath<GlobalState, State>,
    event: CasePath<GlobalEvent, Event>
  ) -> Reducer<GlobalState, GlobalEvent> {
    return .init { globalState, globalEvent in
      guard let localAction = event.extract(from: globalEvent) else {
        return
      }
      self(&globalState[keyPath: value], localAction)
    }
  }

  public func optional() -> Reducer<State?, Event> {
    return .init { state, event in
      if state == nil {
        return
      }
      self.reduce(&state!, event)
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
