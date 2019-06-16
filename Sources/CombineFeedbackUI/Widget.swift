import Combine
import CombineFeedback
import SwiftUI

public struct Widget<S, E>: View {
    // For some reasong using @ObjectBinding private var viewModel: ViewModel<S, E>
    // crashes the compiler
    private let viewModel: ObjectBinding<ViewModel<S, E>>
    private let render: (Context<S, E>) -> AnyView

    public init<R: Renderer>(
        viewModel: ViewModel<S, E>,
        renderer: R
    ) where R.State == S, R.Event == E {
        self.viewModel = ObjectBinding(initialValue: viewModel)
        self.render = renderer.render(context:)
    }

    public init(
        viewModel: ViewModel<S, E>,
        render: @escaping (Context<S, E>) -> AnyView
    ) {
        self.viewModel = ObjectBinding(initialValue: viewModel)
        self.render = render
    }

    public var body: some View {
        return render(Context(viewModel: viewModel.value))
    }
}
