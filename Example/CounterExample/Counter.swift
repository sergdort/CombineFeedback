import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

final class CounterViewModel: ViewModel<CounterViewModel.State, CounterViewModel.Event> {
    struct State {
        var count = 0
    }

    enum Event {
        case increment
        case decrement
    }

    init() {
        super.init(
            initial: State(),
            feedbacks: [],
            scheduler: DispatchQueue.main,
            reducer: CounterViewModel.reducer(state:event:)
        )
    }

    private static func reducer(
        state: State,
        event: Event
    ) -> State {
        switch event {
        case .increment:
            return State(count: state.count + 1)
        case .decrement:
            return State(count: state.count - 1)
        }
    }
}

struct CounterView: View {
    typealias State = CounterViewModel.State
    typealias Event = CounterViewModel.Event
    
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
