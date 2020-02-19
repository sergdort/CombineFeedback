import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

extension SignIn {
    final class ViewModel: CombineFeedbackUI.ViewModel<SignIn.State, SignIn.Event> {
        init(initial: State = State()) {
            super.init(
                initial: initial,
                feedbacks: [
                    ViewModel.whenChangingUserName(api: GithubAPI()),
                    ViewModel.whenSubmiting(api: GithubAPI())
                ],
                reducer: SignIn.reducer
            )
        }

        static func whenChangingUserName(api: GithubAPI) -> Feedback<State, Event> {
            return Feedback.custom { state, consumer in
                state
                    .map {
                        $0.userName
                    }
                    .filter { $0.isEmpty == false }
                    .removeDuplicates()
                    .debounce(
                        for: 0.5,
                        scheduler: DispatchQueue.main
                    )
                    .flatMapLatest { userName in
                        return api.usernameAvailable(username: userName)
                            .map(Event.isAvailable)
                            .enqueue(to: consumer)
                    }
                    .start()
            }
        }

        static func whenSubmiting(api: GithubAPI) -> Feedback<State, Event> {
            return Feedback(effects: { (state) -> AnyPublisher<Event, Never> in
                guard state.status.isSubmitting else {
                    return Empty().eraseToAnyPublisher()
                }

                return api
                    .singIn(username: state.userName, email: state.email, password: state.password)
                    .map(Event.didSignIn)
                    .eraseToAnyPublisher()
            })
        }
    }
}

struct SignInView: View {
    typealias State = SignIn.State
    typealias Event = SignIn.Event

    let context: Context<State, Event>

    var body: some View {
        return Form {
            Section {
                HStack {
                    TextField(
                        "Username",
                        text: context.binding(for: \.userName, event: Event.didChageUserName)
                    )
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .textContentType(.username)
                    Group {
                        if context.status.isCheckingUserName {
                            Activity(style: .medium)
                        } else {
                            Image(systemName: context.isAvailable ? "hand.thumbsup.fill" : "xmark.seal.fill")
                        }
                    }
                }
                Text(context.userName)
                TextField(
                    "Email",
                    text: context.binding(for: \.email)
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.emailAddress)
                TextField(
                    "Password",
                    text: context.binding(for: \.password)
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.newPassword)
                TextField(
                    "Repeat Password",
                    text: context.binding(for: \.repeatPassword)
                )
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .textContentType(.newPassword)
            }
            Section {
                // Seems like a bug in switch view amimation
                // ¯\_(ツ)_/¯
                Toggle(isOn: context.binding(for: \.termsAccepted)) {
                    Text("Accept Terms and Conditions")
                }
                // When wrapping `UISwitch` into UIViewRepresentable
                // everything works
                HStack(
                    alignment: .center,
                    spacing: 8
                ) {
                    Text("Accept Terms and Conditions")
                    Spacer()
                    Switch(isOn: context.binding(for: \.termsAccepted))
                }
            }
            Section {
                ZStack {
                    HStack {
                        Spacer()
                        Button(action: context.action(for: .signIn)) {
                            Text("Sign In")
                                .multilineTextAlignment(.center)
                        }
                        .disabled(!context.canSubmit)
                        Spacer()
                    }
                    Group {
                        if context.status.isSubmitting {
                            Activity(style: .medium)
                        } else {
                            EmptyView()
                        }
                    }
                }
            }
        }
    }
}

#if DEBUG
struct SignIn_Previews_Default: PreviewProvider {
    static var previews: some View {
        Widget(
            viewModel: SignIn.ViewModel(
                initial: SignIn.State(
                    userName: "",
                    email: "",
                    password: "",
                    repeatPassword: "",
                    termsAccepted: false,
                    status: .idle,
                    isAvailable: false
                )
            ),
            render: SignInView.init(context:)
        )
    }
}
#endif

extension Publisher where Failure == Never {
    func promoteError<E: Error>(to: E.Type) -> Publishers.MapError<Self, E> {
        return mapError { _ -> E in }
    }
}

final class GithubAPI {
    func usernameAvailable(username: String) -> AnyPublisher<Bool, Never> {
        // Fake implementation
        return Result.Publisher(Int.random(in: 0...100) % 2 == 0)
            .delay(for: 0.3, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }

    func singIn(username: String, email: String, password: String) -> AnyPublisher<Bool, Never> {
        // Fake implementation
        return Result.Publisher(true)
            .delay(for: 0.3, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

extension String {
    var urlEscaped: String {
        return addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
}

struct Switch: UIViewRepresentable {
    let isOn: Binding<Bool>
    let animated = true

    func makeUIView(context: UIViewRepresentableContext<Switch>) -> UISwitch {
        let view = UISwitch(frame: .zero)

        view.addTarget(
            context.coordinator,
            action: #selector(Target.action(_:)),
            for: .valueChanged
        )

        return view
    }

    func updateUIView(_ uiView: UISwitch, context: UIViewRepresentableContext<Switch>) {
        context.coordinator._action = { view in
            self.isOn.wrappedValue = view.isOn
        }
        uiView.setOn(isOn.wrappedValue, animated: animated)
    }

    func makeCoordinator() -> Target {
        return Target()
    }

    static func dismantleUIView(_ uiView: UISwitch, coordinator: Switch.Target) {
        uiView.removeTarget(
            coordinator,
            action: #selector(Target.action(_:)),
            for: .valueChanged
        )
    }

    class Target: NSObject {
        override init() {
            super.init()
        }

        fileprivate var _action: ((UISwitch) -> Void)?

        @objc
        func action(_ sender: UISwitch) {
            _action?(sender)
        }
    }
}
