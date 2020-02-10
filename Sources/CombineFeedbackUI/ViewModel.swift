import Combine
import CombineFeedback
import Foundation

open class ViewModel<State, Event> {
    public let state: AnyPublisher<State, Never>
    internal let initial: State
    private let input = Feedback<State, Update>.input

    public init(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        reducer: @escaping (State, Event) -> State
    ) {
        self.initial = initial
        self.state = Publishers.system(
            initial: initial,
            feedbacks: feedbacks.map { $0.mapEvent(Update.event) }
                .appending(self.input.feedback),
            reduce: { state, update in
                switch update {
                case .event(let event):
                    return reducer(state, event)
                case .mutation(let mutation):
                    return mutation.mutate(state)
                }
            }
        )
    }

    open func send(event: Event) {
        self.input.observer(.event(event))
    }

    open func mutate<V>(keyPath: WritableKeyPath<State, V>, value: V) {
        self.input.observer(.mutation(Mutation(keyPath: keyPath, value: value)))
    }

    func mutate(with mutation: Mutation<State>) {
        self.input.observer(.mutation(mutation))
    }

    private enum Update {
        case event(Event)
        case mutation(Mutation<State>)
    }
}

public struct Mutation<State> {
    let mutate: (State) -> State

    init<V>(keyPath: WritableKeyPath<State, V>, value: V) {
        self.mutate = { state in
            var copy = state

            copy[keyPath: keyPath] = value

            return copy
        }
    }

    init(mutate: @escaping (State) -> State) {
        self.mutate = mutate
    }
}

extension Array {
    func appending(_ element: Element) -> [Element] {
        var copy = self

        copy.append(element)

        return copy
    }
}
