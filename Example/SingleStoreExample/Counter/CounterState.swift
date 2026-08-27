import CombineFeedback

struct Counter: StateMachine {
  struct State: Equatable {
    var count = 0
  }

  enum Event {
    case increment
    case decrement
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    reducer
  }

  var reducer: Reducer<State, Event> {
    Reducer { state, event in
      switch event {
      case .increment:
        state.count += 1
      case .decrement:
        state.count -= 1
      }
    }
  }
}
