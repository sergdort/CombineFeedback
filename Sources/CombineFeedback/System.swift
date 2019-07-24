import Combine
import Foundation

extension Publishers {
    public static func system<State, Event, S: Scheduler>(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        scheduler: S,
        reduce: @escaping (State, Event) -> State
    ) -> AnyPublisher<State, Never> {
        return Deferred { () -> AnyPublisher<State, Never> in
            let state = CurrentValueSubject<State, Never>(initial)

            let events = feedbacks
                .map { feedbacks in
                    return feedbacks.events(state.eraseToAnyPublisher())
                }

            return Publishers.MergeMany(events)
                .receive(on: scheduler)
                .scan(initial, reduce)
                .prepend(initial)
                .handleEvents(receiveOutput: state.send)
                .receive(on: scheduler)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
