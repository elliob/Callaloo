//
//  HouseholdOnboardingView.swift
//  Callaloo
//

import SwiftUI

struct HouseholdOnboardingView: View {
    @Environment(SessionStore.self) private var session
    @State private var mode: Mode = .choose
    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var isBusy = false

    enum Mode {
        case choose
        case create
        case join
    }

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .choose:
                    chooseContent
                case .create:
                    createContent
                case .join:
                    joinContent
                }
            }
            .animation(.easeInOut(duration: 0.25), value: mode)
            .navigationTitle(mode == .choose ? "Welcome" : "Your family")
            .navigationBarTitleDisplayMode(mode == .choose ? .inline : .large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if mode != .choose {
                        Button {
                            mode = .choose
                            session.clearError()
                        } label: {
                            Label("Back", systemImage: "chevron.backward")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.signOut()
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityHint("Signs out of your account on this device")
                }
            }
        }
    }

    private var chooseContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Image("CallalooMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 8) {
                    Text("How will you use Callaloo?")
                        .font(.title2.bold())
                    Text("Pick the path that matches you. You can always invite others later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                roleCard(
                    title: "I shop for my family",
                    subtitle: "Create the list, see order requests, and invite parents.",
                    systemImage: "cart.fill",
                    isPrimary: true
                ) {
                    mode = .create
                }

                roleCard(
                    title: "I’m a parent",
                    subtitle: "Join with a code from your family admin and request orders from the list.",
                    systemImage: "person.2.fill",
                    isPrimary: false
                ) {
                    mode = .join
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: CallalooTheme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .callalooAuthBackground()
    }

    private func roleCard(
        title: String,
        subtitle: String,
        systemImage: String,
        isPrimary: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(isPrimary ? .white : Color.accentColor)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle()
                            .fill(isPrimary ? Color.white.opacity(0.22) : Color.accentColor.opacity(0.15))
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(isPrimary ? .white : .primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(isPrimary ? .white.opacity(0.9) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isPrimary ? .white.opacity(0.8) : Color.accentColor.opacity(0.7))
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Group {
                    if isPrimary {
                        RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusLarge, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusLarge, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusLarge, style: .continuous)
                                    .strokeBorder(Color.accentColor.opacity(0.22), lineWidth: 1)
                            }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var createContent: some View {
        formShell {
            VStack(alignment: .leading, spacing: 14) {
                Text("Family name")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("e.g. The Elliots", text: $familyName)
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    }
            }

            Button {
                Task { await create() }
            } label: {
                Text("Create family space")
            }
            .buttonStyle(CallalooPrimaryCTAButtonStyle(isLoading: isBusy))
            .disabled(isBusy || familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message = session.lastErrorMessage {
                errorBanner(message)
            }
        }
    }

    private var joinContent: some View {
        formShell {
            VStack(alignment: .leading, spacing: 14) {
                Text("Invite code")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Paste the code from your admin", text: $inviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .padding(14)
                    .background {
                        RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    }
            }

            Button {
                Task { await join() }
            } label: {
                Text("Join family")
            }
            .buttonStyle(CallalooPrimaryCTAButtonStyle(isLoading: isBusy))
            .disabled(isBusy || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let message = session.lastErrorMessage {
                errorBanner(message)
            }
        }
    }

    private func formShell<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content()
            }
            .padding(22)
            .frame(maxWidth: CallalooTheme.contentMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .callalooAuthBackground()
        .scrollDismissesKeyboard(.interactively)
    }

    private func errorBanner(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusSmall, style: .continuous)
                    .fill(Color.red.opacity(0.1))
            }
    }

    private func create() async {
        session.clearError()
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await HouseholdService.createHousehold(
                displayName: familyName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            session.lastErrorMessage = HouseholdService.userFacingMessage(forCallableError: error)
        }
    }

    private func join() async {
        session.clearError()
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await HouseholdService.redeemParentInvite(inviteId: inviteCode)
        } catch {
            session.lastErrorMessage = HouseholdService.userFacingMessage(forCallableError: error)
        }
    }
}

#Preview {
    HouseholdOnboardingView()
        .environment(SessionStore())
}
