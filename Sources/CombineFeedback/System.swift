import Combine
import Foundation

extension Publishers {
    public static func system<State, Event>(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        scheduler: DispatchQueueScheduler = .main,
        reduce: @escaping (State, Event) -> State
    ) -> AnyPublisher<State, Never> {
        return Publishers.Deferred { () -> AnyPublisher<State, Never> in
            let state = CurrentValueSubject<State, Never>(initial)

            let events = feedbacks
                .map { feedbacks in
                    return feedbacks.events(state.eraseToAnyPublisher())
                }

            return Publishers.MergeMany(events)
                .receive(on: scheduler)
                .scan(initial, reduce)
                .handleEvents(receiveOutput: state.send)
                .receive(on: scheduler)
                .eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
}
