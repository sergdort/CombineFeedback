import Combine
import CombineFeedback

enum SignIn {
    struct State {
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

    static func reducer(state: inout State, event: Event) {
        switch event {
        case .didChageUserName(let userName):
            state.userName = userName
            state.status = userName.isEmpty ? .idle : .checkingUserName
        case .isAvailable(let isAvailable):
            state.isAvailable = isAvailable
            state.status = .idle
        case .didFail(let error):
            state.status = .failed(error)
        case .signIn:
            state.status = .submitting
        case .didSignIn:
            state.status = .idle
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
