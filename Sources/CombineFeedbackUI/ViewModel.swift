import Combine
import CombineFeedback
import Foundation
import SwiftUI

open class ViewModel<S, E>: BindableObject {
    private let input = Feedback<S, Update>.input
    public let didChange = PassthroughSubject<Void, Never>()
    private var sink: Subscribers.Sink<AnyPublisher<S, Never>>?
    public private(set) var state: S {
        didSet {
            self.didChange.send(())
        }
    }

    public init(
        initial: S,
        feedbacks: [Feedback<S, E>],
        reducer: @escaping (S, E) -> S
    ) {
        self.state = initial
        self.sink = Publishers.system(
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
        ).sink { state in
            self.state = state
        }
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

    deinit {
        sink?.cancel()
    }
}

extension Feedback {
    func mapEvent<U>(_ f: @escaping (Event) -> U) -> Feedback<State, U> {
        return Feedback<State, U>(events: { state -> AnyPublisher<U, Never> in
            self.events(state).map(f).eraseToAnyPublisher()
        })
    }
}

extension Array {
    func appending(_ element: Element) -> [Element] {
        var copy = self

        copy.append(element)

        return copy
    }
}
