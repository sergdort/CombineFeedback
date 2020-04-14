import CombineFeedback

enum Counter {
    struct State: Equatable {
        var count = 0
    }

    enum Event {
        case increment
        case decrement
    }

    static func reducer() -> Reducer<State, Event> {
        .init { state, event in
            switch event {
            case .increment:
                state.count += 1
            case .decrement:
                state.count -= 1
            }
        }
    }
}

