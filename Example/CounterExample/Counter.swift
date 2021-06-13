import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

extension Counter {
  final class ViewModel: Store<Counter.State, Counter.Event> {
    init() {
      super.init(
        initial: State(),
        feedbacks: [],
        reducer: Counter.reducer(),
        dependency: ()
      )
    }
  }
}

struct CounterView: View {
  typealias State = Counter.State
  typealias Event = Counter.Event

  let store: Store<State, Event>

  init(store: Store<State, Event>) {
    self.store = store
    logInit(of: self)
  }

  var body: some View {
    logBody(of: self)
    return WithViewContext(store: store) { context in
      Form {
        Button(action: {
          context.send(event: .decrement)
        }) {
          Text("-").font(.largeTitle)
        }
        Button(action: {
          context.send(event: .increment)
        }) {
          Text("+").font(.largeTitle)
        }
        if context.count >= 0 {
          ForEach((0 ..< context.count).reversed(), id: \.self) { item in
            Text("\(item)")
          }
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
