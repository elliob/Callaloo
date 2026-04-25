//
//  LoginView.swift
//  Callaloo
//

import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isBusy = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Email") {
                    TextField("you@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                        .textContentType(isRegistering ? .newPassword : .password)
                }

                Section {
                    Button(isRegistering ? "Create account" : "Sign in with email") {
                        Task { await submitEmail() }
                    }
                    .disabled(isBusy || email.isEmpty || password.count < 6)

                    Button(isRegistering ? "Already have an account?" : "Need an account?") {
                        isRegistering.toggle()
                    }
                    .buttonStyle(.borderless)
                }

                Section("Or") {
                    Button {
                        Task { await submitGoogle() }
                    } label: {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                    }
                    .disabled(isBusy)
                }

                if let message = session.lastErrorMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Callaloo")
            .overlay {
                if isBusy { ProgressView().scaleEffect(1.2) }
            }
        }
    }

    private func submitEmail() async {
        session.clearError()
        isBusy = true
        defer { isBusy = false }
        do {
            if isRegistering {
                try await AuthActions.registerEmail(email: email, password: password)
            } else {
                try await AuthActions.signInEmail(email: email, password: password)
            }
        } catch {
            session.lastErrorMessage = error.localizedDescription
        }
    }

    private func submitGoogle() async {
        session.clearError()
        isBusy = true
        defer { isBusy = false }
        do {
            try await AuthActions.signInWithGoogle()
        } catch {
            session.lastErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    LoginView()
        .environment(SessionStore())
}
