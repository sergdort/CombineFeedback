import Combine
import CombineFeedback
import SwiftUI

public struct Widget<R: Renderer>: View {
    @ObjectBinding private var viewModel: ViewModel<R.State, R.Event>
    private let renderer: R

    public init(viewModel: ViewModel<R.State, R.Event>, renderer: R) {
        self.viewModel = viewModel
        self.renderer = renderer
    }

    public var body: some View {
        return renderer.render(context: Context(viewModel: viewModel))
    }
}

extension Feedback {
    static var input: (feedback: Feedback<State, Event>, observer: (Event) -> Void) {
        let subject = PassthroughSubject<Event, Never>()
        let feedback = Feedback<State, Event>(events: { _ in
            subject.eraseToAnyPublisher()
        })
        return (feedback, subject.eraseToAnySubject().send)
    }
}
