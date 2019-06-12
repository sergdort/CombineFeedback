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

    func render(context: Context<State, Event>) -> AnyView {
        if context.count <= 0 {
            return renderStack(context: context)
        }

        return renderList(context: context)
    }

    private func renderStack(context: Context<State, Event>) -> AnyView {
        HStack {
            Button(action: {
                context.send(event: .decrement)
            }) {
                Text("-").font(.largeTitle)
            }
            Text("\(context.count)")
            Button(action: {
                context.send(event: .increment)
            }) {
                Text("+").font(.largeTitle)
            }
        }.eraseToAnyView()
    }

    func renderList(context: Context<State, Event>) -> AnyView {
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
        }.eraseToAnyView()
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}
