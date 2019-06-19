import Combine
import CombineFeedback
import Foundation

open class ViewModel<State, Event> {
    public let state: AnyPublisher<State, Never>
    internal let initial: State
    private let input = Feedback<State, Update>.input

    public init<S: Scheduler>(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        scheduler: S,
        reducer: @escaping (State, Event) -> State
    ) {
        self.initial = initial
        self.state = Publishers.system(
            initial: initial,
            feedbacks: feedbacks.map { $0.mapEvent(Update.event) }
                .appending(self.input.feedback),
            scheduler: scheduler,
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

    private enum Update {
        case event(Event)
        case mutation(Mutation)
    }

    private struct Mutation {
        let mutate: (State) -> State

        init<V>(keyPath: WritableKeyPath<State, V>, value: V) {
            self.mutate = { state in
                var copy = state

                copy[keyPath: keyPath] = value

                return copy
            }
        }
    }
}

extension Feedback {
    func mapEvent<U>(_ f: @escaping (Event) -> U) -> Feedback<State, U> {
        return Feedback<State, U>(events: { state -> AnyPublisher<U, Never> in
            self.events(state).map(f).eraseToAnyPublisher()
        })
    }

    static var input: (feedback: Feedback, observer: (Event) -> Void) {
        let subject = PassthroughSubject<Event, Never>()
        let feedback = Feedback(events: { _ in
            return subject
        })
        return (feedback, subject.send)
    }
}

extension Array {
    func appending(_ element: Element) -> [Element] {
        var copy = self

        copy.append(element)

        return copy
    }
}
