import Combine
import CombineFeedback
import SwiftUI

open class ViewModel<S, E>: BindableObject {
    private let input = Feedback<S, E>.input
    public let didChange = PassthroughSubject<Void, Never>()
    public private(set) var state: S {
        didSet {
            didChange.send(())
        }
    }

    public init(
        initial: S,
        feedbacks: [Feedback<S, E>],
        reducer: @escaping (S, E) -> S
    )  {
        self.state = initial
        _ = Publishers.system(
            initial: initial,
            feedbacks: feedbacks.appending(input.feedback),
            reduce: reducer
        ).sink { state in
            self.state = state
        }
    }

    public final func send(event: E) {
        input.observer.send(event: event)
    }
}

extension Array {
    func appending(_ element: Element) -> [Element] {
        var copy = self

        copy.append(element)

        return copy
    }
}
