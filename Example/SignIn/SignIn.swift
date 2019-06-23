import Combine
import CombineFeedback
import CombineFeedbackUI
import SwiftUI

final class SignInViewModel: ViewModel<SignInViewModel.State, SignInViewModel.Event> {
    init(initial: State = State()) {
        super.init(
            initial: initial,
            feedbacks: [
                SignInViewModel.whenChangingUserName(api: GithubAPI()),
                SignInViewModel.whenSubmiting(api: GithubAPI())
            ],
            scheduler: RunLoop.main,
            reducer: SignInViewModel.reduce
        )
    }
    
    static func whenChangingUserName(api: GithubAPI) -> Feedback<State, Event> {
        return Feedback(events: { state$ in
            state$
                .map {
                    $0.userName
                }
                .filter { $0.isEmpty == false }
                .removeDuplicates()
                .debounce(
                    for: 0.5,
                    scheduler: RunLoop.main
                )
                .flatMapLatest { userName in
                    return api.usernameAvailable(username: userName)
                        .map(Event.isAvailable)
                }
        })
    }
    
    static func whenSubmiting(api: GithubAPI) -> Feedback<State, Event> {
        return Feedback(effects: { (state) -> AnyPublisher<Event, Never> in
            guard state.status.isSubmitting else {
                return Publishers.Empty().eraseToAnyPublisher()
            }
            
            return api
                .singIn(username: state.userName, email: state.email, password: state.password)
                .map(Event.didSignIn)
                .eraseToAnyPublisher()
        })
    }
    
    private static func reduce(state: State, event: Event) -> State {
        switch event {
        case .didChageUserName(let userName):
            return state
                .set(\.userName, userName)
                .set(\.status, userName.isEmpty ? .idle : .checkingUserName)
        case .isAvailable(let isAvailable):
            return state
                .set(\.isAvailable, isAvailable)
                .set(\.status, .idle)
        case .didFail(let error):
            return state.set(\.status, .failed(error))
        case .signIn:
            return state.set(\.status, .submitting)
        case .didSignIn(_):
            return state.set(\.status, .idle)
        }
    }
    
    struct State: Builder {
        var userName = ""
        var email = ""
        var password = ""
        var repeatPassword = ""
        var termsAccepted = false
        var status = Status.idle
        fileprivate(set) var isAvailable = false
        
        var canSubmit: Bool {
            return isAvailable
                && !userName.isEmpty
                && !email.isEmpty
                && !password.isEmpty
                && !repeatPassword.isEmpty
                && password == repeatPassword
                && termsAccepted
        }
    }
    
    enum Status {
        case checkingUserName
        case failed(Error)
        case idle
        case submitting
        case signedIn
        
        var isCheckingUserName: Bool {
            switch self {
            case .checkingUserName:
                return true
            default:
                return false
            }
        }
        
        var isSubmitting: Bool {
            switch self {
            case .submitting:
                return true
            default:
                return false
            }
        }
        
        var isSignedIn: Bool {
            switch self {
            case .signedIn:
                return true
            default:
                return false
            }
        }
    }
    
    enum Event {
        case isAvailable(Bool)
        case didFail(Error)
        case didSignIn(Bool)
        case didChageUserName(String)
        case signIn
    }
}

struct SignInView: View {
    typealias State = SignInViewModel.State
    typealias Event = SignInViewModel.Event
    
    private let context: Context<State, Event>
    
    init(context: Context<State, Event>) {
        self.context = context
    }
    
    var body: some View {
        return Form {
            Section {
                HStack {
                    TextField(
                        context.binding(for: \.userName, event: Event.didChageUserName),
                        placeholder: Text("Username")
                    )
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                    Group {
                        if context.status.isCheckingUserName {
                            Activity(style: .medium)
                        } else {
                            Image(systemName: context.isAvailable ? "hand.thumbsup.fill" : "xmark.seal.fill")
                        }
                    }
                }
                TextField(
                    context.binding(for: \.email),
                    placeholder: Text("Email")
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.emailAddress)
                TextField(
                    context.binding(for: \.password),
                    placeholder: Text("Password")
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
                TextField(
                    context.binding(for: \.repeatPassword),
                    placeholder: Text("Repeat Password")
                )
                .textFieldStyle(.roundedBorder)
                .textContentType(.newPassword)
            }
            Section {
                Toggle(isOn: context.binding(for: \.termsAccepted)) {
                    Text("Accept Terms and Conditions")
                }
            }
            Section {
                ZStack {
                    HStack {
                        Spacer()
                        Button(action: context.action(for: .signIn)) {
                            return Text("Sign In")
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
            viewModel: SignInViewModel(
                initial: SignInViewModel.State(
                    userName: "",
                    email: "",
                    password: "",
                    repeatPassword: "",
                    termsAccepted: false,
                    status: .idle,
                    isAvailable: false
                )
            ),
            render: SignInView.init
        )
    }
}
#endif

extension Publisher where Failure == Never {
    func promoteError<E: Error>(to: E.Type) -> Publishers.MapError<Self, E> {
        return self.mapError { _ -> E in }
    }
}

protocol Builder {}
extension Builder {
    func set<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> Self {
        var copy = self
        copy[keyPath: keyPath] = value
        return copy
    }
}

final class GithubAPI {
    func usernameAvailable(username: String) -> AnyPublisher<Bool, Never> {
        // Fake implementation
        return Publishers.Just(Int.random(in: 0...100) % 2 == 0)
            .delay(for: 0.3, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    func singIn(username: String, email: String, password: String) -> AnyPublisher<Bool, Never> {
        // Fake implementation
        return Publishers.Just(true)
            .delay(for: 0.3, scheduler: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

extension String {
    var urlEscaped: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
    }
}
