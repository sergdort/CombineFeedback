import SwiftUI
import Combine
import CombineFeedback
import CombineFeedbackUI

extension TrafficLight {
    final class ViewModel: CombineFeedbackUI.ViewModel<TrafficLight.State, TrafficLight.Event> {

        init() {
            super.init(
                initial: .red,
                feedbacks: [
                    ViewModel.whenRed(),
                    ViewModel.whenYellow(),
                    ViewModel.whenGreen()
                ],
                scheduler: DispatchQueue.main,
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

struct TrafficLightView: View {
    let context: Context<TrafficLight.State, TrafficLight.Event>
    
    var body: some View {
        return VStack {
            Circle()
                .frame(width: 150, height: 150)
                .animation(.default)
                .foregroundColor(Color.red.opacity(context.isRed ? 1 : 0.5))
            Circle()
                .frame(width: 150, height: 150)
                .animation(.default)
                .foregroundColor(Color.yellow.opacity(context.isYellow ? 1 : 0.5))
            Circle()
                .frame(width: 150, height: 150)
                .animation(.default)
                .foregroundColor(Color.green.opacity(context.isGreen ? 1 : 0.5))
        }
        .padding()
        .background(Color.black)
    }
}

#if DEBUG
struct TrafficLightView_Preview: PreviewProvider {
    
    static var previews: some View {
        Widget(
            viewModel: TrafficLight.ViewModel(),
            render: TrafficLightView.init
        )
    }
}
#endif


