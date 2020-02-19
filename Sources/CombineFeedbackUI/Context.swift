import SwiftUI

@dynamicMemberLookup
public struct Context<State, Event> {
    private let state: State
    private let send: (Event) -> Void
    private let mutate: (Mutation<State>) -> Void

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

    public func view<LocalState, LocalEvent>(
        value: WritableKeyPath<State, LocalState>,
        event: @escaping (LocalEvent) -> Event
    ) -> Context<LocalState, LocalEvent> {
        return Context<LocalState, LocalEvent>(
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
    
    public func action(for event: Event) -> () -> Void {
        return {
            self.send(event: event)
        }
    }
}
