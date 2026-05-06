//
//  AdminFamilyView.swift
//  Callaloo
//

import SwiftUI
import UIKit

struct AdminFamilyView: View {
    @Environment(SessionStore.self) private var session
    @State private var inviteId: String?
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var householdId: String? { session.userProfile?.householdId }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Invite a parent", systemImage: "person.badge.plus")
                            .font(.title3.bold())
                        Text("Generate a code and send it to your parent. They choose “I’m a parent” after signing in and paste the code.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        Task { await generateInvite() }
                    } label: {
                        Text(inviteId == nil ? "Generate invite code" : "Generate new code")
                    }
                    .buttonStyle(CallalooPrimaryCTAButtonStyle(isLoading: isBusy))
                    .disabled(isBusy || householdId == nil)

                    if let inviteId {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Active code")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(inviteId)
                                .font(.body.monospaced())
                                .textSelection(.enabled)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                }

                            HStack(spacing: 12) {
                                Button {
                                    UIPasteboard.general.string = inviteId
                                } label: {
                                    Label("Copy code", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(CallalooSecondaryCTAButtonStyle())

                                ShareLink(item: inviteId, subject: Text("Callaloo invite"), message: Text("Use this code in Callaloo to join our family list: \(inviteId)")) {
                                    Label("Share code", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(CallalooSecondaryCTAButtonStyle())
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .callalooCardSurface(cornerRadius: CallalooTheme.cornerRadiusLarge)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusSmall, style: .continuous)
                                    .fill(Color.red.opacity(0.1))
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
                .frame(maxWidth: CallalooTheme.contentMaxWidth)
                .frame(maxWidth: .infinity)
            }
            .callalooListBackground()
            .navigationTitle("Family")
            .callalooLogOutButton()
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
            errorMessage = HouseholdService.userFacingMessage(forCallableError: error)
        }
    }
}
