import SwiftUI
import Combine

@dynamicMemberLookup
public final class Context<State, Event>: ObservableObject {
    @Published
    private var state: State
    private var bag = Set<AnyCancellable>()
    private let send: (Event) -> Void
    private let mutate: (Mutation<State>) -> Void
    
    init(store: Store<State, Event>) {
        self.state = store.state
        self.send = store.send
        self.mutate = store.mutate
        store.$state.assign(to: \.state, on: self).store(in: &bag)
    }
        
    public init(
        state: State,
        send: @escaping (Event) -> Void,
        mutate: @escaping (Mutation<State>) -> Void
    ) {
        self.state = state
        self.send = send
        self.mutate = mutate
    }
    
    public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
        return state[keyPath: keyPath]
    }
    
    public func send(event: Event) {
        send(event)
    }
    
    public func view<LocalState: Equatable, LocalEvent>(
        value: WritableKeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Context<LocalState, LocalEvent> {
        view(value: value, event: event, removeDuplicates: ==)
    }

    public func view<LocalState, LocalEvent>(
        value: WritableKeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event,
        removeDuplicates: @escaping (LocalState, LocalState) -> Bool
    ) -> Context<LocalState, LocalEvent> {
        let localContext = Context<LocalState, LocalEvent>(
            state: state[keyPath: value],
            send: { localEvent in
                self.send(event(localEvent))
            },
            mutate: { (mutation: Mutation<LocalState>)  in
                let superMutation: Mutation<State> = Mutation  { state in
                    mutation.mutate(&state[keyPath: value])
                }
                self.mutate(superMutation)
            }
        )
        
        $state.map(value)
            .removeDuplicates(by: removeDuplicates)
            .assign(to: \.state, on: localContext)
            .store(in: &localContext.bag)
        
        return localContext
    }
    
    public func binding<U>(for keyPath: KeyPath<State, U>, event: @escaping (U) -> Event) -> Binding<U> {
        return Binding(
            get: {
                self.state[keyPath: keyPath]
            },
            set: {
                self.send(event: event($0))
            }
        )
    }
    
    public func binding<U>(for keyPath: WritableKeyPath<State, U>) -> Binding<U> {
        return Binding(
            get: {
                self.state[keyPath: keyPath]
            },
            set: {
                self.mutate(Mutation(keyPath: keyPath, value: $0))
            }
        )
    }
    
    public func subject<U>(for keyPath: KeyPath<State, U>) -> AnyPublisher<U, Never> {
        CurrentValueSubject<U, Never>(self.state[keyPath: keyPath]).eraseToAnyPublisher()
    }
    
    public func action(for event: Event) -> () -> Void {
        return {
            self.send(event: event)
        }
    }
}
