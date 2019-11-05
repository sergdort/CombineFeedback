import Foundation
import Combine
import CombineFeedback
import CombineFeedbackUI

extension String {
    var validEmail: Bool {
        let regexp = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", regexp)
        return predicate.evaluate(with: self)
    }

    var validPassword: Bool {
        count > 5
    }
}

public struct Alert: Identifiable {
    var title: String
    var message: String
    public var id: String { message }
}


public final class RegistrationViewModel: ViewModel<RegistrationViewModel.State, RegistrationViewModel.Event> {

    public struct State {
        var email: String = ""
        var password: String = ""
        var firstName: String = ""
        var lastName: String = ""
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
            return Alert(title: "Account created", message: "Welcome \(loggedAccount.email)")
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
            return self == .loading
        }
    }

    public enum Event {
        case register
        case didRegister(LoggedAccount)
        case dismiss
    }

    public init(state: State = State()) {
        super.init(
            initial: state,
            feedbacks: [RegistrationViewModel.whenSubmiting()],
            scheduler: RunLoop.main,
            reducer: RegistrationViewModel.reducer(state:event:)
        )
    }

    private static func whenSubmiting() -> Feedback<State, Event> {
        return Feedback(predicate: { $0.status.isLoading }, effects: { state in
            Just("Account Created")
                .delay(for: 2, scheduler: RunLoop.main)
                .map { _ in
                    LoggedAccount(email: state.email,
                                  password: state.password,
                                  firstName: state.firstName,
                                  lastName: state.lastName)
                }
                .map(Event.didRegister)
                .eraseToAnyPublisher()
        })
    }

    private static func reducer(state: State, event: Event) -> State {
        switch event {
        case .register:
            var state = state
            state.triedToSubmitOnce = true
            state.status = state.valid ? .loading : .idle
            return state
        case let .didRegister(loggedAccount):
            var state = state
            state.status = .idle
            state.loggedAccount = loggedAccount
            return state
        case .dismiss:
            var state = state
            state.dismissed = true
            return state
        }
    }
}
