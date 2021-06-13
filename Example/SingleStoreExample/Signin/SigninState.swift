import Combine
import CombineFeedback
import Foundation

enum SignIn {
  struct Dependencies {
    var signIn: (
      _ userName: String,
      _ email: String,
      _ password: String
    ) -> AnyPublisher<Bool, Never>

    var usernameAvailable: (
      _ username: String
    ) -> AnyPublisher<Bool, Never>
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
    case didChangeUserName(String)
    case signIn
    case dismissAlertTap
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
        state.showSignedInAlert = true
      case .didSignIn:
        state.status = .idle
      case .dismissAlertTap:
        state.showSignedInAlert = false
      }
    }
  }

  static var feedback: Feedback<State, Event, Dependencies> {
    return Feedback.combine(
      whenChangingUserName(),
      whenSubmitting()
    )
  }

  static func whenChangingUserName() -> Feedback<State, Event, Dependencies> {
    return Feedback.custom { state, consumer, dependency in
      state
        .map {
          $0.0.userName
        }
        .filter { $0.isEmpty == false }
        .removeDuplicates()
        .debounce(
          for: 0.5,
          scheduler: DispatchQueue.main
        )
        .flatMapLatest { userName in
          dependency.usernameAvailable(userName)
            .map(Event.isAvailable)
            .enqueue(to: consumer)
        }
        .start()
    }
  }

  static func whenSubmitting() -> Feedback<State, Event, Dependencies> {
    return .middleware { (state: State, dependency: Dependencies) -> AnyPublisher<Event, Never> in
      guard state.status.isSubmitting else {
        return Empty().eraseToAnyPublisher()
      }

      return dependency
        .signIn(state.userName, state.email, state.password)
        .map(Event.didSignIn)
        .eraseToAnyPublisher()
    }
  }
}
