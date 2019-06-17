import Combine
import CombineFeedback
import SwiftUI

public struct Widget<S, E, Content: View>: View {
    private let view: State<Content>
    private let viewPublisher: AnyPublisher<Content, Never>

    public init<R: Renderer>(
        viewModel: ViewModel<S, E>,
        renderer: R
    ) where R.State == S, R.Event == E, R.Content == Content {
        self.init(viewModel: viewModel, render: renderer.render)
    }

    public init(
        viewModel: ViewModel<S, E>,
        render: @escaping (Context<S, E>) -> Content
    ) {
        self.view = State(
            initialValue: render(Context(state: viewModel.initial, viewModel: viewModel))
        )
        self.viewPublisher = viewModel.state
            .map {
                return render(Context(state: $0, viewModel: viewModel))
            }
            .eraseToAnyPublisher()
    }

    public var body: some View {
        return view.value.bind(viewPublisher, to: view.binding)
    }
}

extension View {
    func bind<P: Publisher, Value>(
        _ publisher: P,
        to binding: Binding<Value>
    ) -> SubscriptionView<P, Self> where P.Failure == Never, P.Output == Value {
        return onReceive(publisher) { value in
            binding.value = value
        }
    }
}
