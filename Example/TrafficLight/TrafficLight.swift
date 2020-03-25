import SwiftUI
import Combine
import CombineFeedback
import CombineFeedbackUI

extension TrafficLight {
    final class ViewModel: CombineFeedbackUI.Store<TrafficLight.State, TrafficLight.Event> {

        init() {
            super.init(
                initial: .red,
                feedbacks: [
                    ViewModel.whenRed(),
                    ViewModel.whenYellow(),
                    ViewModel.whenGreen()
                ],
                reducer: TrafficLight.reducer
            )
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

        private static func reduce(state: State, event: Event) -> State {
            switch state {
            case .red:
                return .yellow
            case .yellow:
                return .green
            case .green:
                return .red
            }
        }
    }
}

