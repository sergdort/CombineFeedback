import Combine
import Foundation

extension Publishers {
    public static func system<State, Event>(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        reduce: @escaping Reducer<State, Event>
    ) -> AnyPublisher<State, Never> {
        return Publishers.Feedbackloop(
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
