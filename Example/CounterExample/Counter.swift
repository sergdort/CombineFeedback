import CombineFeedback
import SwiftUI

extension Counter {
  final class ViewModel: Store<Counter.State, Counter.Event> {
    init() {
      super.init(
        initial: State(),
        machine: Counter()
      )
    }
  }
}

struct CounterView: View {
  typealias State = Counter.State
  typealias Event = Counter.Event

  @StoreBinding<State, Event> private var state: State

  init(store: Store<State, Event>) {
    self._state = StoreBinding(store)
    logInit(of: self)
  }

  var body: some View {
    Form {
      Button(action: {
        $state.send(.decrement)
      }) {
        Text("-").font(.largeTitle)
      }
      Button(action: {
        $state.send(.increment)
      }) {
        Text("+").font(.largeTitle)
      }
      if state.count >= 0 {
        ForEach((0 ..< state.count).reversed(), id: \.self) { item in
          Text("\(item)")
        }
      }
    }
  }
}

extension View {
  func eraseToAnyView() -> AnyView {
    return AnyView(self)
  }
}
