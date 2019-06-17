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

struct CounterRenderer: Renderer {
    typealias State = CounterViewModel.State
    typealias Event = CounterViewModel.Event

    func render(context: Context<State, Event>) -> some View {
        return Group {
            if context.count <= 0 {
                renderStack(context: context)
            } else {
                renderList(context: context)
            }
        }
    }

    private func renderStack(context: Context<State, Event>) -> some View {
        return HStack {
            Button(action: {
                context.send(event: .decrement)
            }) {
                return Text("-").font(.largeTitle)
            }
            Text("\(context.count)")
                .iff(context.count%2 != 0) {
                    $0.color(.red)
                }
                .font(.largeTitle)
                .cornerRadius(20, antialiased: false)
            Button(action: {
                context.send(event: .increment)
            }) {
                Text("+").font(.largeTitle)
            }
        }
    }

    func renderList(context: Context<State, Event>) -> some View {
        List {
            Button(action: {
                context.send(event: .decrement)
            }) {
                Text("-").font(.largeTitle)
            }
            ForEach(0...context.count) { (count) in
                Text("\(count)")
            }
            Button(action: {
                context.send(event: .increment)
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
