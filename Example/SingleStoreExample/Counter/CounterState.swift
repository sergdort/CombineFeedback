enum Counter {
    struct State {
        var count = 0
    }

    enum Event {
        case increment
        case decrement
    }

    static func reducer(
        state: inout State,
        event: Event
    ) {
        switch event {
        case .increment:
            state.count += 1
        case .decrement:
            state.count -= 1
        }
    }
}

