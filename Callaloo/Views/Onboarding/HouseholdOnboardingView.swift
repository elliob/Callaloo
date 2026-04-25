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
            .navigationTitle("Your family")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if mode != .choose {
                        Button("Back") { mode = .choose }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        session.signOut()
                    }
                }
            }
        }
    }

    private var chooseContent: some View {
        VStack(spacing: 24) {
            Text("Choose how you use Callaloo.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            VStack(spacing: 16) {
                Button {
                    mode = .create
                } label: {
                    Text("I order for my family")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    mode = .join
                } label: {
                    Text("I’m a parent using the list")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)

            Spacer()
        }
    }

    private var createContent: some View {
        Form {
            Section("Family name") {
                TextField("e.g. Mom & Dad", text: $familyName)
            }
            Section {
                Button("Create family space") {
                    Task { await create() }
                }
                .disabled(isBusy || familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let message = session.lastErrorMessage {
                Section { Text(message).foregroundStyle(.red).font(.footnote) }
            }
        }
        .overlay { if isBusy { ProgressView() } }
    }

    private var joinContent: some View {
        Form {
            Section("Invite code") {
                TextField("Paste the code from your child", text: $inviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            Section {
                Button("Join family") {
                    Task { await join() }
                }
                .disabled(isBusy || inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if let message = session.lastErrorMessage {
                Section { Text(message).foregroundStyle(.red).font(.footnote) }
            }
        }
        .overlay { if isBusy { ProgressView() } }
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
            session.lastErrorMessage = error.localizedDescription
        }
    }

    private func join() async {
        session.clearError()
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await HouseholdService.redeemParentInvite(inviteId: inviteCode)
        } catch {
            session.lastErrorMessage = error.localizedDescription
        }
    }
}

#Preview {
    HouseholdOnboardingView()
        .environment(SessionStore())
}
