import Combine
import CombineFeedback
import Foundation

struct TrafficLight: StateMachine {
  enum State: Equatable {
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

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    Reducer<State, Event> { state, _ in
      switch state {
      case .red:
        state = .yellow
      case .yellow:
        state = .green
      case .green:
        state = .red
      }
    }

    OnChange<State, Event, State>(of: { $0 }) { _ in
      Result.Publisher(Event.next)
        .delay(for: 1, scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
  }
}
