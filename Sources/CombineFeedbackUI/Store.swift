import Combine
import CombineFeedback
import Foundation
import CasePaths

open class Store<State, Event> {
    @Published
    public private(set) var state: State
    private let input = Feedback<State, Update>.input
    private var bag = Set<AnyCancellable>()
    
    public init(
        initial: State,
        feedbacks: [Feedback<State, Event>],
        reducer: Reducer<State, Event>
    ) {
        self.state = initial
        Publishers.FeedbackLoop(
            initial: initial,
            reduce: .init { state, update in
                switch update {
                case .event(let event):
                    reducer(&state, event)
                case .mutation(let mutation):
                    mutation.mutate(&state)
                }
            },
            feedbacks: feedbacks.map {
                $0.pullback(value: \.self, event: /Update.event)
            }
            .appending(self.input.feedback)
        )
        .assign(to: \.state, weakly: self)
        .store(in: &bag)
    }
    
    var context: Context<State, Event> {
        return Context(store: self)
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
    let mutate: (inout State) -> Void
    
    init<V>(keyPath: WritableKeyPath<State, V>, value: V) {
        self.mutate = { state in
            state[keyPath: keyPath] = value
        }
    }
    
    init(mutate: @escaping (inout State) -> Void) {
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


extension Publisher where Self.Failure == Never {
    public func assign<Root: AnyObject>(
        to keyPath: WritableKeyPath<Root, Self.Output>, weakly object: Root) -> AnyCancellable {
        return self.sink { [weak object] (output) in
            object?[keyPath: keyPath] = output
        }
    }
}
