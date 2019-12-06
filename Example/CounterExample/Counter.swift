import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

extension Counter {
    final class ViewModel: CombineFeedbackUI.ViewModel<Counter.State, Counter.Event> {
        init() {
            super.init(
                initial: State(),
                feedbacks: [],
                scheduler: DispatchQueue.main,
                reducer: Counter.reducer(state:event:)
            )
        }
    }
}

struct CounterView: View {
    typealias State = Counter.State
    typealias Event = Counter.Event
    
    let context: Context<State, Event>

    var body: some View {
        Form {
            Button(action: {
                self.context.send(event: .decrement)
            }) {
                return Text("-").font(.largeTitle)
            }
            Text("\(context.count)").font(.largeTitle)
            Button(action: {
                self.context.send(event: .increment)
            }) {
                Text("+").font(.largeTitle)
            }
        }
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}
