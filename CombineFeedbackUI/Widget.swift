import Combine
import SwiftUI

public struct Widget<R: Renderer, S: System>: View where R.State == S.State, R.Event == S.Event {
    private let uiFeedback: SwiftUIFeedback<R>
    private let system: S
    @State private var disposable: AnyCancellable? = nil
    @State private var view: AnyView = EmptyView().eraseToAnyView()

    public init(renderer: R, system: S) {
        self.uiFeedback = SwiftUIFeedback(renderer: renderer)
        self.system = system
    }

    public var body: some View {
        return view.onAppear(perform: viewWillAppear)
            .onDisappear(perform: viewWillDisappear)
    }

    private func viewWillAppear() {
        var feedbacks = system.feedbacks
        feedbacks.append(uiFeedback.bind(to: $view))
        self.disposable = Publishers.system(
            initial: system.initial,
            feedbacks: feedbacks,
            reduce: system.reducer
        )
        .subscribe(EmptySubject())
    }

    private func viewWillDisappear() {
        self.disposable?.cancel()
    }

    private final class EmptySubject<Output, Failure: Error>: Subject {
        func receive<S>(subscriber: S)
            where S: Subscriber, Failure == S.Failure, Output == S.Input {
        }
        func send(_ value: Output) {}
        func send(completion: Subscribers.Completion<Failure>) {}
    }
}

extension View {
    func eraseToAnyView() -> AnyView {
        return AnyView(self)
    }
}
