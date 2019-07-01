import SwiftUI
import Combine
import CombineFeedback
import CombineFeedbackUI

final class TrafficLightViewModel: ViewModel<TrafficLightViewModel.State, TrafficLightViewModel.Event> {
    
    init() {
        super.init(
            initial: .red,
            feedbacks: [
                TrafficLightViewModel.whenRed(),
                TrafficLightViewModel.whenYellow(),
                TrafficLightViewModel.whenGreen()
            ],
            scheduler: DispatchQueue.main,
            reducer: TrafficLightViewModel.reduce
        )
    }
    
    private static func whenRed() -> Feedback<State, Event> {
        return Feedback(effects: { state -> AnyPublisher<Event, Never> in
            guard case .red = state else {
                return Publishers.Empty().eraseToAnyPublisher()
            }
            
            return Publishers.Just(Event.next)
                .delay(for: 1, scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        })
    }
    
    private static func whenYellow() -> Feedback<State, Event> {
        return Feedback(effects: { state -> AnyPublisher<Event, Never> in
            guard case .yellow = state else {
                return Publishers.Empty().eraseToAnyPublisher()
            }
            
            return Publishers.Just(Event.next)
                .delay(for: 1, scheduler: DispatchQueue.main)
                .eraseToAnyPublisher()
        })
    }
    
    private static func whenGreen() -> Feedback<State, Event> {
        return Feedback(effects: { state -> AnyPublisher<Event, Never> in
            guard case .green = state else {
                return Publishers.Empty().eraseToAnyPublisher()
            }
            
            return Publishers.Just(Event.next)
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
}

struct TrafficLightView: View {
    var context: Context<TrafficLightViewModel.State, TrafficLightViewModel.Event>
    
    var body: some View {
        return VStack {
            Circle()
                .frame(width: 200, height: 200)
                .animation(.default)
                .foregroundColor(Color.red.opacity(context.isRed ? 1 : 0.5))
            Circle()
                .frame(width: 200, height: 200)
                .animation(.default)
                .foregroundColor(Color.yellow.opacity(context.isYellow ? 1 : 0.5))
            Circle()
                .frame(width: 200, height: 200)
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
            viewModel: TrafficLightViewModel(),
            render: TrafficLightView.init
        )
    }
}
#endif


