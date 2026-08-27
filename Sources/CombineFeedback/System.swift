import Combine
import Foundation

public extension Publishers {
  static func system<State, Event, M: StateMachine>(
    initial: State,
    machine: M
  ) -> AnyPublisher<State, Never> where M.State == State, M.Event == Event {
    let resolved = machine._resolve()
    return Publishers.FeedbackLoop(
      initial: initial,
      reduce: resolved.reducer,
      feedbacks: resolved.feedbacks
    )
    .eraseToAnyPublisher()
  }
}

public extension Publisher where Output == Never, Failure == Never {
  func start() -> Cancellable {
    return sink(receiveValue: { _ in })
  }
}
