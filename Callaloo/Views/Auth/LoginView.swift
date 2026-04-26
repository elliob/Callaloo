//
//  LoginView.swift
//  Callaloo
//

import SwiftUI

struct LoginView: View {
    @Environment(SessionStore.self) private var session
    @FocusState private var focusedField: Field?
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false
    @State private var isBusy = false

    private enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CallalooTheme.sectionSpacing) {
                    header

                    VStack(alignment: .leading, spacing: 14) {
                        fieldLabel("Email")
                        TextField("you@example.com", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .password }
                            .padding(14)
                            .background {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }

                        fieldLabel("Password")
                        SecureField(isRegistering ? "At least 6 characters" : "Your password", text: $password)
                            .textContentType(isRegistering ? .newPassword : .password)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.go)
                            .onSubmit { Task { await submitEmail() } }
                            .padding(14)
                            .background {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }
                    }

                    Button {
                        Task { await submitEmail() }
                    } label: {
                        Text(isRegistering ? "Create account" : "Sign in")
                    }
                    .buttonStyle(CallalooPrimaryCTAButtonStyle(isLoading: isBusy))
                    .disabled(isBusy || email.isEmpty || password.count < 6)

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isRegistering.toggle()
                            session.clearError()
                        }
                    } label: {
                        Text(isRegistering ? "Already have an account? Sign in" : "Need an account? Register")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)

                    orDivider

                    Button {
                        Task { await submitGoogle() }
                    } label: {
                        Label("Continue with Google", systemImage: "g.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CallalooSecondaryCTAButtonStyle())
                    .disabled(isBusy)

                    if let message = session.lastErrorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusSmall, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            }
                            .accessibilityIdentifier("loginError")
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
                .frame(maxWidth: CallalooTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .callalooAuthBackground()
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if isBusy {
                    Color.black.opacity(0.12)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.15)
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "leaf.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.accentColor, Color.accentColor.opacity(0.35))
                .font(.system(size: 52))
                .accessibilityHidden(true)

            Text("Callaloo")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)

            Text("Shared grocery lists for your family—simple for parents, clear for whoever shops.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 4)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var orDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 1)
            Text("or")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(height: 1)
        }
        .padding(.vertical, 4)
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
