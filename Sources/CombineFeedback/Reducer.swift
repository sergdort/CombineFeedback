
public typealias Reducer<State, Event> = (State, Event) -> State

public func combine<State, Event>(
    _ reducers: Reducer<State, Event>...
) -> Reducer<State, Event> {
    return { state, event in
        var newState = state

        for reducer in reducers {
            newState = reducer(newState, event)
        }

        return newState
    }
}

public func pullback<LocalState, GlobalState, LocalEvent, GlobalEvent>(
    _ reducer: @escaping Reducer<LocalState, LocalEvent>,
    value: WritableKeyPath<GlobalState, LocalState>,
    event: WritableKeyPath<GlobalEvent, LocalEvent?>
) -> Reducer<GlobalState, GlobalEvent> {
    return { globalState, globalEvent in
        guard let localAction = globalEvent[keyPath: event] else {
            return globalState
        }
        var globalStateCopy = globalState
        globalStateCopy[keyPath: value] = reducer(globalState[keyPath: value], localAction)

        return globalStateCopy
    }
}
