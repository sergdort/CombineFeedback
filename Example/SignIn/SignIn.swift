import Combine
import CombineFeedback
import SwiftUI

extension SignIn {
  final class ViewModel: Store<SignIn.State, SignIn.Event> {
    init(initial: State = State()) {
      super.init(
        initial: initial,
        feedbacks: [
          ViewModel.whenChangingUserName(api: GithubAPI()),
          ViewModel.whenSubmitting(api: GithubAPI())
        ],
        reducer: SignIn.reducer(),
        dependency: ()
      )
    }

    static func whenChangingUserName(api: GithubAPI) -> Feedback<State, Event, Void> {
      return Feedback.custom { state, consumer, _ in
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
            api.usernameAvailable(username: userName)
              .map(Event.isAvailable)
              .enqueue(to: consumer)
          }
      }
    }

    static func whenSubmitting(api: GithubAPI) -> Feedback<State, Event, Void> {
      return .middleware { (state, _) -> AnyPublisher<Event, Never> in
        guard state.status.isSubmitting else {
          return Empty().eraseToAnyPublisher()
        }

        return api
          .signIn(username: state.userName, email: state.email, password: state.password)
          .map(Event.didSignIn)
          .eraseToAnyPublisher()
      }
    }
  }
}

struct SignInView: View {
  typealias State = SignIn.State
  typealias Event = SignIn.Event

  let store: Store<State, Event>

  init(store: Store<State, Event>) {
    self.store = store
    logInit(of: self)
  }

  var body: some View {
    logBody(of: self)
    return WithContextView(store: store) { context in
      Form {
        Section {
          HStack {
            TextField(
              "Username",
              text: context.binding(for: \.userName, event: Event.didChangeUserName)
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .textContentType(.username)
            if context.status.isCheckingUserName {
              Activity(style: .medium)
            } else {
              Image(systemName: context.isAvailable ? "hand.thumbsup.fill" : "xmark.seal.fill")
            }
          }
          TextField(
            "Email",
            text: context.binding(for: \.email, event: Event.emailDidChange)
          )
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .textContentType(.emailAddress)
          TextField(
            "Password",
            text: context.binding(for: \.password, event: Event.passwordDidChange)
          )
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .textContentType(.newPassword)
          TextField(
            "Repeat Password",
            text: context.binding(for: \.repeatPassword, event: Event.repeatPasswordDidChange)
          )
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .textContentType(.newPassword)
        }
        Section {
          Toggle(isOn: context.binding(for: \.termsAccepted, event: Event.termsDidChange)) {
            Text("Accept Terms and Conditions")
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
      .alert(
        isPresented: context.binding(for: \.showSignedInAlert, event: .dismissAlertTap),
        content: {
          Alert(title: Text("Signed In"))
        }
      )
    }
  }
}

extension Publisher where Failure == Never {
  func promoteError<E: Error>(to: E.Type) -> Publishers.MapError<Self, E> {
    return mapError { _ -> E in }
  }
}

final class GithubAPI {
  func usernameAvailable(username: String) -> AnyPublisher<Bool, Never> {
    // Fake implementation
    return Result.Publisher(Int.random(in: 0 ... 100) % 2 == 0)
      .delay(for: 0.3, scheduler: DispatchQueue.main)
      .eraseToAnyPublisher()
  }

  func signIn(username: String, email: String, password: String) -> AnyPublisher<Bool, Never> {
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
