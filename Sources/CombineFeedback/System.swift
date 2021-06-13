import Combine
import Foundation

public extension Publishers {
  static func system<State, Event, Dependency>(
    initial: State,
    feedbacks: [Feedback<State, Event, Dependency>],
    reduce: Reducer<State, Event>,
    dependency: Dependency
  ) -> AnyPublisher<State, Never> {
    return Publishers.FeedbackLoop(
      initial: initial,
      reduce: reduce,
      feedbacks: feedbacks,
      dependency: dependency
    )
    .eraseToAnyPublisher()
  }
}

public extension Publisher where Output == Never, Failure == Never {
  func start() -> Cancellable {
    return sink(receiveValue: { _ in })
  }
}
