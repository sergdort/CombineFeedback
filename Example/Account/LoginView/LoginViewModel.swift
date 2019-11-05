import Foundation
import Combine
import CombineFeedback
import CombineFeedbackUI

extension LoginViewModel {
    public struct State {
        var email = ""
        var password = ""
        var triedToSubmitOnce = false
        var status = Status.idle
        var loggedAccount: LoggedAccount?
        var dismissed: Bool = false

        public init() {
        }

        var alertMessage: Alert? {
            guard let loggedAccount = loggedAccount else {
                return nil
            }
            return Alert(title: "Welcome back", message: "\(loggedAccount.firstName)")
        }

        var invalidEmailMessage: String {
            invalidEmail ? "Invalid E-mail" : ""
        }

        var invalidPasswordMessage: String {
            invalidPassword ? "Invalid Password" : ""
        }

        var valid: Bool {
            invalidEmail == false && invalidPassword == false
        }

        private var invalidEmail: Bool {
            triedToSubmitOnce && !email.validEmail
        }

        private var invalidPassword: Bool {
            triedToSubmitOnce && password.count <= 5
        }
    }

    public enum Status {
        case idle
        case loading

        var isLoading: Bool {
            if case .loading = self {
                return true
            }
            return false
        }
    }

    public enum Event {
        case login
        case didSignin(LoggedAccount)
        case dismiss
    }
}

public final class LoginViewModel: ViewModel<LoginViewModel.State, LoginViewModel.Event> {

    init(state: State = State()) {
        super.init(
            initial: state,
            feedbacks: [LoginViewModel.whenSigning()],
            scheduler: RunLoop.main,
            reducer: LoginViewModel.reducer(state:event:)
        )
    }

    private static func whenSigning() -> Feedback<State, Event> {
        Feedback(predicate: { $0.status.isLoading }, effects: { (state: State) in
            Just(())
                .delay(for: 2, scheduler: RunLoop.main)
                .map { _ in
                    LoggedAccount(email: state.email,
                                  password: state.password,
                                  firstName: "Diego",
                                  lastName: "Chohfi")
                }
            .map(Event.didSignin)
            .eraseToAnyPublisher()
        })
    }

    private static func reducer(state: State, event: Event) -> State {
        switch event {
        case .login:
            var state = state
            state.triedToSubmitOnce = true
            if state.valid {
                state.status = .loading
            }
            return state
        case let .didSignin(account):
            var state = state
            state.status = .idle
            state.loggedAccount = account
            return state
        case .dismiss:
            var state = state
            state.dismissed = true
            return state
        }
    }
}
