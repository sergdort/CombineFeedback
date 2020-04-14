import Combine
import CombineFeedback
import Foundation

enum SignIn {
    struct State: Equatable {
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

        enum Status: Equatable {
            case checkingUserName
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
        case didSignIn(Bool)
        case didChangeUserName(String)
        case signIn
    }

    static func reducer() -> Reducer<State, Event> {
        return .init { state, event in
            switch event {
            case .didChangeUserName(let userName):
                state.userName = userName
                state.status = userName.isEmpty ? .idle : .checkingUserName
            case .isAvailable(let isAvailable):
                state.isAvailable = isAvailable
                state.status = .idle
            case .signIn:
                state.status = .submitting
            case .didSignIn:
                state.status = .idle
            }
        }
    }

    static var feedback: Feedback<State, Event> {
        return Feedback.combine(
            whenChangingUserName(api: GithubAPI()),
            whenSubmitting(api: GithubAPI())
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

    static func whenSubmitting(api: GithubAPI) -> Feedback<State, Event> {
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
