import SwiftUI

@dynamicMemberLookup
public struct Context<State, Event> {
    private let state: State
    private let viewModel: ViewModel<State, Event>
    
    public init(state: State, viewModel: ViewModel<State, Event>) {
        self.state = state
        self.viewModel = viewModel
    }
    
    public subscript<U>(dynamicMember keyPath: KeyPath<State, U>) -> U {
        return state[keyPath: keyPath]
    }
    
    public func send(event: Event) {
        viewModel.send(event: event)
    }
    
    public func binding<U>(for keyPath: KeyPath<State, U>, event: @escaping (U) -> Event) -> Binding<U> {
        return Binding(
            getValue: {
                self.state[keyPath: keyPath]
            },
            setValue: {
                self.viewModel.send(event: event($0))
            }
        )
    }
    
    public func binding<U>(for keyPath: WritableKeyPath<State, U>) -> Binding<U> {
        return Binding(
            getValue: {
                self.state[keyPath: keyPath]
            },
            setValue: {
                self.viewModel.mutate(keyPath: keyPath, value: $0)
            }
        )
    }
    
    public func action(for event: Event) -> () -> Void {
        return {
            self.send(event: event)
        }
    }
}
