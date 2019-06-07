import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

struct CounterSystem: System {
    struct State {
        var count = 0
    }

    enum Event {
        case increment
        case decrement
    }

    let initial = State()
    let feedbacks: [Feedback<CounterSystem.State, CounterSystem.Event>] = []

    func reducer(
        state: CounterSystem.State,
        event: CounterSystem.Event
    ) -> CounterSystem.State {
        switch event {
        case .increment:
            return State(count: state.count + 1)
        case .decrement:
            return State(count: state.count - 1)
        }
    }
}

struct CounterRenderer: Renderer {
    typealias State = CounterSystem.State
    typealias Event = CounterSystem.Event

    func render(state: State, callback: Callback<Event>) -> AnyView {
        if state.count <= 0 {
            return renderStack(state: state, callback: callback)
        }

        return renderList(state: state, callback: callback)
    }

    private func renderStack(state: State, callback: Callback<Event>) -> AnyView {
        HStack {
            Button(action: {
                callback.send(event: .decrement)
            }) {
                Text("-").font(.largeTitle)
            }
            Text("Hello World \(state.count)")
            Button(action: {
                callback.send(event: .increment)
            }) {
                Text("+").font(.largeTitle)
            }
        }.eraseToAnyView()
    }

    func renderList(state: State, callback: Callback<Event>) -> AnyView {
        List {
            Button(action: {
                callback.send(event: .decrement)
            }) {
                Text("-").font(.largeTitle)
            }
            ForEach(0...state.count) { (count) in
                Text("Hello World \(count)")
            }
            Button(action: {
                callback.send(event: .increment)
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
