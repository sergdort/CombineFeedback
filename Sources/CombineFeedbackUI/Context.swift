import SwiftUI

@dynamicMemberLookup
public struct Context<S, E> {
    private let viewModel: ViewModel<S, E>
    
    public init(viewModel: ViewModel<S, E>) {
        self.viewModel = viewModel
    }
    
    public subscript<U>(dynamicMember keyPath: KeyPath<S, U>) -> U {
        return viewModel.state[keyPath: keyPath]
    }
    
    public func send(event: E) {
        viewModel.send(event: event)
    }
    
    public func binding<U>(for keyPath: WritableKeyPath<S, U>) -> Binding<U> {
        return Binding(
            getValue: {
                self.viewModel.state[keyPath: keyPath]
            },
            setValue: {
                self.viewModel.mutate(keyPath: keyPath, value: $0)
            }
        )
    }
}
