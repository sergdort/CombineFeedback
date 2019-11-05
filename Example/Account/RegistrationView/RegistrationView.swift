import Foundation
import SwiftUI
import Combine
import CombineFeedback
import CombineFeedbackUI

public struct RegistrationView: View {
    public typealias State = RegistrationViewModel.State
    public typealias Event = RegistrationViewModel.Event

    private let context: Context<State, Event>
    private let loginViewModel: LoginViewModel

    public init(context: Context<State, Event>, loginViewModel: LoginViewModel) {
        self.context = context
        self.loginViewModel = loginViewModel
    }

    private var submitButton: some View {
        Button("Create Account", action: { self.context.send(event: .register) })
    }

    private var nameSection: some View {
        Section(header: Text("You")) {
            HStack {
                TextField("First name", text: self.context.binding(for: \.firstName))
                TextField("Last name", text: self.context.binding(for: \.lastName))
            }
        }
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

    private var navigateToSignin: some View {
        HStack {
            Activity(isAnimating: .constant(self.context.status.isLoading), style: .medium)
            NavigationLink("Sign In", destination: Widget(viewModel: self.loginViewModel, render: LoginView.init))
        }
    }

    private var dismissButton: some View {
        Button("Dismiss") { self.context.send(event: .dismiss) }
    }

    private func welcomeAlert(alert: Alert) -> SwiftUI.Alert {
        SwiftUI.Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")) {
            self.context.send(event: .dismiss)
        })
    }

    public var body: some View {
        NavigationView {
            Form {
                self.nameSection
                self.emailSection
                self.passwordSection
                self.submitButton
            }
            .disabled(self.context.status.isLoading)
            .alert(item: .constant(self.context.alertMessage), content: self.welcomeAlert(alert:))
            .navigationBarTitle(Text("Account"))
            .navigationBarItems(leading: self.dismissButton, trailing: self.navigateToSignin)
        }
    }
}
