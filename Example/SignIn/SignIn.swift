import CombineFeedback
import SwiftUI

extension SignIn {
  final class ViewModel: Store<SignIn.State, SignIn.Event> {
    init(initial: State = State()) {
      let api = GithubAPI()
      super.init(
        initial: initial,
        machine: SignIn(
          dependencies: SignIn.Dependencies(
            signIn: { await api.signIn(username: $0, email: $1, password: $2) },
            usernameAvailable: { await api.usernameAvailable(username: $0) }
          )
        )
      )
    }
  }
}

struct SignInView: View {
  typealias State = SignIn.State
  typealias Event = SignIn.Event

  @StoreBinding<State, Event> private var state: State

  init(store: Store<State, Event>) {
    self._state = StoreBinding(store)
    logInit(of: self)
  }

  var body: some View {
    Form {
      Section {
        HStack {
          TextField(
            "Username",
            text: $state.binding(for: \.userName, event: Event.didChangeUserName)
          )
          .textFieldStyle(RoundedBorderTextFieldStyle())
          .textContentType(.username)
          if state.status.isCheckingUserName {
            Spinner(style: .medium)
          } else {
            Image(systemName: state.isAvailable ? "hand.thumbsup.fill" : "xmark.seal.fill")
          }
        }
        TextField(
          "Email",
          text: $state.binding(for: \.email, event: Event.emailDidChange)
        )
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .textContentType(.emailAddress)
        TextField(
          "Password",
          text: $state.binding(for: \.password, event: Event.passwordDidChange)
        )
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .textContentType(.newPassword)
        TextField(
          "Repeat Password",
          text: $state.binding(for: \.repeatPassword, event: Event.repeatPasswordDidChange)
        )
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .textContentType(.newPassword)
      }
      Section {
        Toggle(isOn: $state.binding(for: \.termsAccepted, event: Event.termsDidChange)) {
          Text("Accept Terms and Conditions")
        }
      }
      Section {
        ZStack {
          HStack {
            Spacer()
            Button(action: $state.action(for: .signIn)) {
              Text("Sign In")
                .multilineTextAlignment(.center)
            }
            .disabled(!state.canSubmit)
            Spacer()
          }
          Group {
            if state.status.isSubmitting {
              Spinner(style: .medium)
            } else {
              EmptyView()
            }
          }
        }
      }
    }
    .alert(
      isPresented: $state.binding(for: \.showSignedInAlert, event: .dismissAlertTap),
      content: {
        Alert(title: Text("Signed In"))
      }
    )
  }
}

final class GithubAPI {
  func usernameAvailable(username: String) async -> Bool {
    // Fake implementation
    do {
      try await Task.sleep(nanoseconds: 300_000_000)
    } catch {
      return false
    }
    return Int.random(in: 0 ... 100) % 2 == 0
  }

  func signIn(username: String, email: String, password: String) async -> Bool {
    // Fake implementation
    do {
      try await Task.sleep(nanoseconds: 300_000_000)
    } catch {
      return false
    }
    return true
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
