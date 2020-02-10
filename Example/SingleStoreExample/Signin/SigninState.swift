import Combine
import CombineFeedback

enum SignIn {
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
    }

    enum Event {
        case isAvailable(Bool)
        case didFail(Error)
        case didSignIn(Bool)
        case didChageUserName(String)
        case signIn
    }

    static func reducer(state: State, event: Event) -> State {
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
        case .didSignIn:
            return state.set(\.status, .idle)
        }
    }

    static var feedback: Feedback<State, Event> {
        return Feedback.combine(
            whenChangingUserName(api: GithubAPI()),
            whenSubmiting(api: GithubAPI())
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
