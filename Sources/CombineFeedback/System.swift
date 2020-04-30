import Combine
import Foundation

extension Publishers {
    public static func system<State, Event>(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        reduce: Reducer<State, Event>
    ) -> AnyPublisher<State, Never> {
        return Publishers.FeedbackLoop(
            initial: initial,
            reduce: reduce,
            feedbacks: feedbacks
        )
        .eraseToAnyPublisher()
    }
}

extension Publisher where Output == Never, Failure == Never {
    public func start() -> Cancellable {
        return sink(receiveValue: { _ in })
    }
}
