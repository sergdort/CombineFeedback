import Combine
import CombineFeedback
import Foundation
import SwiftUI

open class ViewModel<S, E>: BindableObject {
    public let didChange = PassthroughSubject<Void, Never>()
    public let state: AnyPublisher<S, Never>
    internal let initial: S
    private let input = Feedback<S, Update>.input

    public init(
        initial: S,
        feedbacks: [Feedback<S, E>],
        reducer: @escaping (S, E) -> S
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

    public final func send(event: E) {
        self.input.observer(.event(event))
    }

    public func mutate<V>(keyPath: WritableKeyPath<S, V>, value: V) {
        self.input.observer(.mutation(Mutation(keyPath: keyPath, value: value)))
    }

    private enum Update {
        case event(E)
        case mutation(Mutation)
    }

    private struct Mutation {
        let mutate: (S) -> S

        init<V>(keyPath: WritableKeyPath<S, V>, value: V) {
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
