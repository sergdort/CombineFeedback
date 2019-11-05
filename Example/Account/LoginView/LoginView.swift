import Foundation
import SwiftUI
import Combine
import CombineFeedback
import CombineFeedbackUI

public struct LoginView: View {
    public typealias State = LoginViewModel.State
    public typealias Event = LoginViewModel.Event

    private let context: Context<State, Event>

    public init(context: Context<State, Event>) {
        self.context = context
    }

    private var submitButton: some View {
        Button("Login") { self.context.send(event: .login) }
    }

    private var emailSection: some View {
        Section(header: Text("Email"), footer: Text(self.context.invalidEmailMessage)) {
            TextField("Email", text: self.context.binding(for: \.email))
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .autocapitalization(.none)
        }
    }

    private var passwordSection: some View {
        Section(header: Text("Password"), footer: Text(self.context.invalidPasswordMessage)) {
            SecureField("Password", text: self.context.binding(for: \.password))
                .textContentType(.newPassword)
        }
    }

    private func welcomeAlert(alert: Alert) -> SwiftUI.Alert {
        SwiftUI.Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")) {
            self.context.send(event: .dismiss)
        })
    }

    public var body: some View {
        Form {
            self.emailSection
            self.passwordSection
            self.submitButton
        }
        .alert(item: .constant(self.context.alertMessage), content: self.welcomeAlert(alert:))
        .navigationBarItems(trailing: Activity(isAnimating: .constant(self.context.status.isLoading), style: .medium))
        .navigationBarTitle(Text("Account"))
    }
}
