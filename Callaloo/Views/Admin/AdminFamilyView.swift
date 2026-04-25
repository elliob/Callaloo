//
//  AdminFamilyView.swift
//  Callaloo
//

import SwiftUI

struct AdminFamilyView: View {
    @Environment(SessionStore.self) private var session
    @State private var inviteId: String?
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var householdId: String? { session.userProfile?.householdId }

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite a parent") {
                    Text("Generate a code and send it to your parent. They choose “I’m a parent” after signing in and paste the code.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Generate new invite code") {
                        Task { await generateInvite() }
                    }
                    .disabled(isBusy || householdId == nil)

                    if let inviteId {
                        LabeledContent("Code") {
                            Text(inviteId)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                        }

                        ShareLink(item: inviteId, subject: Text("Callaloo invite"), message: Text("Use this code in Callaloo to join our family list: \(inviteId)")) {
                            Label("Share code", systemImage: "square.and.arrow.up")
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
            }
            .navigationTitle("Family")
        }
    }

    private func generateInvite() async {
        guard let householdId else { return }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        do {
            inviteId = try await HouseholdService.createParentInvite(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
