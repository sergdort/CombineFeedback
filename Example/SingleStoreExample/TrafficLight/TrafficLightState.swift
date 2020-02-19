import Combine
import CombineFeedback

enum TrafficLight {
    enum State {
        case red
        case yellow
        case green

        var isRed: Bool {
            switch self {
            case .red:
                return true
            default:
                return false
            }
        }

        var isYellow: Bool {
            switch self {
            case .yellow:
                return true
            default:
                return false
            }
        }

        var isGreen: Bool {
            switch self {
            case .green:
                return true
            default:
                return false
            }
        }
    }

    enum Event {
        case next
    }

    static func reducer(state: inout State, event: Event) {
        switch state {
        case .red:
            state = .yellow
        case .yellow:
            state = .green
        case .green:
            state = .red
        }
    }

    static var feedback: Feedback<State, Event> {
        return Feedback.combine(whenRed(), whenYellow(), whenGreen())
    }

    private static func whenRed() -> Feedback<State, Event> {
        return Feedback(effects: { state -> AnyPublisher<Event, Never> in
            guard case .red = state else {
                return Empty().eraseToAnyPublisher()
            }

            return Result.Publisher(Event.next)
                .delay(for: 1, scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        })
    }

    private static func whenYellow() -> Feedback<State, Event> {
        return Feedback(effects: { state -> AnyPublisher<Event, Never> in
            guard case .yellow = state else {
                return Empty().eraseToAnyPublisher()
            }

            return Result.Publisher(Event.next)
                .delay(for: 1, scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        })
    }

    private static func whenGreen() -> Feedback<State, Event> {
        return Feedback(effects: { state -> AnyPublisher<Event, Never> in
            guard case .green = state else {
                return Empty().eraseToAnyPublisher()
            }

            return Result.Publisher(Event.next)
                .delay(for: 1, scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        })
    }

}
