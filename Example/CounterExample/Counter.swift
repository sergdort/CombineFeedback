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
        reducer: Counter.reducer()
      )
    }
  }
}

struct CounterView: View {
  typealias State = Counter.State
  typealias Event = Counter.Event

  @ObservedObject
  var context: Context<State, Event>

  init(context: Context<State, Event>) {
    self.context = context
    logInit(of: self)
  }

  var body: some View {
    logBody(of: self)
    return Form {
      Button(action: {
        self.context.send(event: .decrement)
      }) {
        Text("-").font(.largeTitle)
      }
      Button(action: {
        self.context.send(event: .increment)
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

extension View {
  func eraseToAnyView() -> AnyView {
    return AnyView(self)
  }
}
