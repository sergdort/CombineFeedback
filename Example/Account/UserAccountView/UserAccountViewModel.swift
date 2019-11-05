import Foundation
import Combine
import CombineFeedback
import CombineFeedbackUI

public struct LoggedAccount: Equatable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
}

extension UserAccountViewModel {
    public struct State {
        var screen: Screen = .home
        var loggedAccount: LoggedAccount?
    }

    public enum Event {
        case dismiss
        case register
        case didAuthenticate(LoggedAccount)
        case signout
    }

    public enum Screen {
        case home
        case signingUp

        var isSigningUp: Bool {
            if case .signingUp = self {
                return true
            }
            return false
        }
    }
}

public final class UserAccountViewModel: ViewModel<UserAccountViewModel.State, UserAccountViewModel.Event> {
    public init() {
        let initial = State()
        super.init(initial: initial,
                   feedbacks: [],
                   scheduler: RunLoop.main,
                   reducer: UserAccountViewModel.reducer(state:event:))
    }

    private static func reducer(state: State, event: Event) -> State {
        switch event {
        case .dismiss:
            var state = state
            state.screen = .home
            return state
        case .register:
            var state = state
            state.screen = .signingUp
            return state
        case let .didAuthenticate(account):
            var state = state
            state.loggedAccount = account
            return state
        case .signout:
            var state = state
            state.loggedAccount = nil
            return state
        }
    }
}
