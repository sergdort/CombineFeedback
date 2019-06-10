import Combine
import CombineFeedback
import SwiftUI

public struct Widget<R: Renderer>: View {
    @ObjectBinding private var viewModel: ViewModel<R.State, R.Event>
    private let renderer: AnyRenderer<R>

    public init(viewModel: ViewModel<R.State, R.Event>, renderer: R) {
        self.viewModel = viewModel
        self.renderer = AnyRenderer(renderer: renderer, callback: viewModel.send)
    }

    public var body: some View {
        return renderer.map(viewModel.state)
    }

    private struct AnyRenderer<R: Renderer> {
        let renderer: R
        let callback: (R.Event) -> Void

        func map(_ state: R.State) -> AnyView {
            return renderer.render(state: state, callback: Callback(send: callback))
        }
    }
}

extension Feedback {
    static var input: (feedback: Feedback<State, Event>, observer: Callback<Event>) {
        let subject = PassthroughSubject<Event, Never>()
        let feedback = Feedback<State, Event>(events: { _ in
            subject.eraseToAnyPublisher()
        })
        return (feedback, Callback(subject: subject.eraseToAnySubject()))
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }

    func bind<P: Publisher, Value>(
        _ publisher: P,
        to state: Binding<Value>
    ) -> SubscriptionView<P, Self> where P.Failure == Never, P.Output == Value {
        return onReceive(publisher) { value in
            state.value = value
        }
    }
}
