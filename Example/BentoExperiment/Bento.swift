import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI
import UIKit

protocol BentoViewModel: AnyObject {
    associatedtype State
    associatedtype Event

    var state: AnyPublisher<State, Never> { get }

    func send(event: Event)
}

protocol BentoRenderer {
    associatedtype State
    associatedtype Event

    init(observer: @escaping (Event) -> Void)

    func render(state: State) -> AnyView
}

final class BentoViewController<V: BentoViewModel, R: BentoRenderer>: UIHostingController<AnyView> where V.State == R.State, V.Event == R.Event {
    private let viewModel: V
    private let renderer: R
    private var binding: Cancellable = AnyCancellable {}
    private var didBind = false

    init(viewModel: V, renderer: R.Type) {
        self.viewModel = viewModel
        self.renderer = renderer.init(observer: viewModel.send)
        super.init(rootView: EmptyView().eraseToAnyView())
    }

    @objc dynamic required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.didBind == false {
            self.bindViewModel()
            self.didBind = true
        }
    }

    func bindViewModel() {
        binding = viewModel.state
            .map(renderer.render)
            .sink { [weak self] view in
                self?.rootView = view
        }
    }
}

extension Feedback {
    static var input: (feedback: Feedback<State, Event>, observer: Callback<Event>) {
        let subject = PassthroughSubject<Event, Never>()
        let feedback = Feedback<State, Event>(effects: { _ in
            subject.eraseToAnyPublisher()
        })
        return (feedback, Callback(subject: subject.eraseToAnySubject()))
    }
}
