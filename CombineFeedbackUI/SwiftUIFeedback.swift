import SwiftUI
import Combine
import CombineFeedback

struct SwiftUIFeedback<R: Renderer> {
    private let renderer: R

    init(renderer: R) {
        self.renderer = renderer
    }

    func bind(to view: Binding<AnyView>) -> Feedback<R.State, R.Event> {
        return Feedback<R.State, R.Event>(effects: { state in
            return AnyPublisher<R.Event, Never> { observer in
                observer.receive(subscription: Subscriptions.empty)
                view.value = self.renderer.render(
                    state: state,
                    callback: Callback(subscriber: observer)
                )
            }
        })
    }
}
