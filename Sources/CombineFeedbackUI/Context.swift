import SwiftUI

@dynamicMemberLookup
public struct Context<S, E> {
    private let state: S
    private let viewModel: ViewModel<S, E>
    
    public init(state: S, viewModel: ViewModel<S, E>) {
        self.state = state
        self.viewModel = viewModel
    }
    
    public subscript<U>(dynamicMember keyPath: KeyPath<S, U>) -> U {
        return state[keyPath: keyPath]
    }
    
    public func send(event: E) {
        viewModel.send(event: event)
    }
    
    public func binding<U>(for keyPath: WritableKeyPath<S, U>) -> Binding<U> {
        return Binding(
            getValue: {
                self.state[keyPath: keyPath]
            },
            setValue: {
                self.viewModel.mutate(keyPath: keyPath, value: $0)
            }
        )
    }
}
