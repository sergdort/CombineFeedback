import Foundation
import SwiftUI
import Combine
import CombineFeedback
import CombineFeedbackUI

public struct UserAccountView: View {

    public typealias State = UserAccountViewModel.State
    public typealias Event = UserAccountViewModel.Event

    private let context: Context<State, Event>

    private let loginViewModel: LoginViewModel
    private let registrationViewModel: RegistrationViewModel

    private let cancellable: AnyCancellable

    public init(context: Context<State, Event>) {
        self.context = context
        self.loginViewModel = LoginViewModel()
        self.registrationViewModel = RegistrationViewModel()

        self.cancellable = Publishers.Merge(self.loginViewModel.state.filter { $0.dismissed }.map(\.loggedAccount),
                                            self.registrationViewModel.state.filter { $0.dismissed }.map(\.loggedAccount))
            .receive(on: RunLoop.main)
            .sink { loggedAccount in
                if let loggedAccount = loggedAccount {
                    context.send(event: .didAuthenticate(loggedAccount))
                }
                context.send(event: .dismiss)
            }
    }

    private var registerButton: some View {
        Button("Register") { self.context.send(event: .register) }
    }

    private func accountButton(account: LoggedAccount) -> some View {
        Button("Logout from \(account.email)") { self.context.send(event: .signout) }
    }

    public var body: some View {
        Form {
            Section(header: Text("Account")) {
                if self.context.loggedAccount == nil {
                    self.registerButton
                } else {
                    self.accountButton(account: self.context.loggedAccount!)
                }
            }
        }
        .sheet(
            isPresented: .constant(self.context.screen.isSigningUp),
            onDismiss: { self.context.send(event: .dismiss) },
            content: {
                Widget(
                    viewModel: self.registrationViewModel,
                    render: {
                        RegistrationView(context: $0, loginViewModel: self.loginViewModel)
                    }
                )
            }
        )
        .navigationBarTitle(Text("Account"), displayMode: .inline)
    }
}
