import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

final class TimerViewModel: ViewModel<TimerViewModel.State, TimerViewModel.Event> {
    
    struct State: Builder {
        var displayTime: String = TimerViewModel.emptyTime
        var time: Date = Date()
        var latestPausedTime: Date? = Date()
        var timePaused: TimeInterval = 0
        var isPaused: Bool = true
    }
    
    private static let updateInterval: TimeInterval = 0.1
    
    enum Event {
        case startPause
        case reset
        case heartBeat
    }
    
    init() {
        super.init(
            initial: State(),
            feedbacks: [TimerViewModel.createHeartBeat()],
            scheduler: DispatchQueue.main,
            reducer: TimerViewModel.reducer(state:event:)
        )
    }
    
    private static func createHeartBeat() -> Feedback<State, Event> {
        return Feedback(events: { (statePublisher: AnyPublisher<State, Never>) -> AnyPublisher<Event, Never> in
            return Timer.publish(every: TimerViewModel.updateInterval, on: .main, in: .default)
                .autoconnect()
                .map({ _ in
                    return Event.heartBeat
                })
                .eraseToAnyPublisher()
        })
    }
    
    private static var emptyTime: String {
        return TimerViewModel.timeFormatter.string(from: Date(timeIntervalSinceReferenceDate: 0),
                                                   to: Date(timeIntervalSinceReferenceDate: 0))!
        
    }
    
    private static var timeFormatter: DateComponentsFormatter = {
        let dateFormatter = DateComponentsFormatter()
        dateFormatter.unitsStyle = .abbreviated
        dateFormatter.allowedUnits = [.hour, .minute, .second]
        return dateFormatter
    }()
    
    private static func displayTime(_ startTime: Date, _ negativeDelta: TimeInterval) -> String {
        let adjustedStartTime = Date(timeInterval: negativeDelta, since: startTime)
        return timeFormatter.string(from: adjustedStartTime, to: Date()) ?? emptyTime
    }
    
    private static func reducer(state: State, event: Event) -> State {
        switch event {
            
        case .startPause:
            if state.isPaused {
                let moreDeltaTime = Date().timeIntervalSince(state.latestPausedTime!)
                return state.set(\.timePaused, state.timePaused + moreDeltaTime)
                    .set(\.latestPausedTime, nil)
                    .set(\.isPaused, false)
            } else {
                return state.set(\.latestPausedTime, Date()).set(\.isPaused, true)
            }
            
        case .reset:
            return state.set(\.time, Date())
                .set(\.displayTime, emptyTime)
                .set(\.timePaused, 0)
                .set(\.latestPausedTime, Date())
                .set(\.isPaused, true)
            
        case .heartBeat:
            if !state.isPaused {
                let newTime: String = displayTime(state.time, state.timePaused)
                return state.set(\.displayTime, newTime)
            }
            return state
        }
    }
}

struct TimerView: View {
    typealias State = TimerViewModel.State
    typealias Event = TimerViewModel.Event
    
    let context: Context<State, Event>
    
    var body: some View {
        Form {
            Text("\(context.displayTime)").font(.largeTitle)
            
            Button(action: {
                self.context.send(event: .startPause)
            }) {
                return Text(self.context.isPaused ? "Start" : "Pause").font(.largeTitle)
            }
            
            Button(action: {
                self.context.send(event: .reset)
            }) {
                Text("Reset").font(.largeTitle)
            }
        }
    }
}

