import CombineFeedback
import Foundation

struct SignIn: StateMachine {
  let dependencies: Dependencies

  struct Dependencies {
    var signIn: (
      _ userName: String,
      _ email: String,
      _ password: String
    ) async -> Bool

    var usernameAvailable: (
      _ username: String
    ) async -> Bool
  }

  private struct SignInRequest: Equatable {
    var userName: String
    var email: String
    var password: String
  }

  struct State: Equatable {
    var userName = ""
    var email = ""
    var password = ""
    var repeatPassword = ""
    var termsAccepted = false
    var status = Status.idle
    var showSignedInAlert = false
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
    case emailDidChange(String)
    case passwordDidChange(String)
    case didChangeUserName(String)
    case repeatPasswordDidChange(String)
    case termsDidChange(Bool)
    case signIn
    case dismissAlertTap
  }

  @StateMachineBuilder<State, Event>
  var body: some StateMachine<State, Event> {
    reducer
    whenChangingUserName
    whenSubmitting
  }

  var reducer: Reducer<State, Event> {
    Reducer { state, event in
      switch event {
      case .didChangeUserName(let userName):
        state.userName = userName
        state.status = userName.isEmpty ? .idle : .checkingUserName
      case .emailDidChange(let email):
        state.email = email
      case .passwordDidChange(let password):
        state.password = password
      case .repeatPasswordDidChange(let repeatPassword):
        state.repeatPassword = repeatPassword
      case .termsDidChange(let termsAccepted):
        state.termsAccepted = termsAccepted
      case .isAvailable(let isAvailable):
        state.isAvailable = isAvailable
        state.status = .idle
      case .signIn:
        state.status = .submitting
        state.showSignedInAlert = true
      case .didSignIn:
        state.status = .idle
      case .dismissAlertTap:
        state.showSignedInAlert = false
      }
    }
  }

  private var whenChangingUserName: OnChange<State, Event, String> {
    OnChange(of: { state in
      state.userName.isEmpty ? nil : state.userName
    }) { userName async in
      do {
        try await Task.sleep(nanoseconds: 500_000_000)
      } catch {
        return .isAvailable(false)
      }
      let isAvailable = await dependencies.usernameAvailable(userName)
      return .isAvailable(isAvailable)
    }
  }

  private var whenSubmitting: OnChange<State, Event, SignInRequest> {
    OnChange(of: { state -> SignInRequest? in
      guard state.status.isSubmitting else { return nil }
      return SignInRequest(
        userName: state.userName,
        email: state.email,
        password: state.password
      )
    }) { request async in
      let didSignIn = await dependencies.signIn(request.userName, request.email, request.password)
      return .didSignIn(didSignIn)
    }
  }
}
