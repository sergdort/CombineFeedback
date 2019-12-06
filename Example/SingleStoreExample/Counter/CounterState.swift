enum Counter {
    struct State: Builder {
        var count = 0
    }

    enum Event {
        case increment
        case decrement
    }

    static func reducer(
        state: State,
        event: Event
    ) -> State {
        switch event {
        case .increment:
            return state.set(\.count, state.count + 1)
        case .decrement:
            return state.set(\.count, state.count - 1)
        }
    }
}

