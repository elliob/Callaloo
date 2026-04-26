//
//  AdminListView.swift
//  Callaloo
//

import SwiftUI
import FirebaseFirestore

struct AdminListView: View {
    @Environment(SessionStore.self) private var session
    @State private var model = ListItemsModel()
    @State private var newTitle = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var householdId: String? { session.userProfile?.householdId }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.items) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body.weight(.semibold))
                                if !item.notes.isEmpty {
                                    Text(item.notes)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 8)
                            Button {
                                Task { await toggleFavorite(item) }
                            } label: {
                                Image(systemName: item.isFavorite ? "star.fill" : "star")
                                    .font(.body)
                                    .foregroundStyle(item.isFavorite ? Color.yellow : Color.secondary)
                                    .symbolRenderingMode(.hierarchical)
                                    .frame(width: 36, height: 36)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(item.isFavorite ? "Remove favorite" : "Mark favorite")
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Hide", systemImage: "eye.slash", role: .destructive) {
                                Task { await setActive(item, active: false) }
                            }
                        }
                    }
                } header: {
                    Label("Visible to parents", systemImage: "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .callalooListBackground()
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            session.signOut()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More options")
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    } else if let listenErr = model.lastListenError {
                        Text(listenErr)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    HStack(alignment: .center, spacing: 10) {
                        TextField("Add an item", text: $newTitle)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background {
                                RoundedRectangle(cornerRadius: CallalooTheme.cornerRadiusMedium, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            }
                            .submitLabel(.done)
                            .onSubmit { Task { await addItem() } }

                        Button {
                            Task { await addItem() }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                        .accessibilityLabel("Add item")
                    }
                    .padding(.bottom, 6)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .mask {
                            LinearGradient(
                                colors: [.black, .black.opacity(0.92)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .ignoresSafeArea(edges: .bottom)
                }
            }
            .task(id: householdId) {
                guard let householdId else { return }
                model.start(householdId: householdId)
            }
            .onDisappear {
                model.stop()
            }
        }
    }

    private func addItem() async {
        guard let householdId else { return }
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document()
            let order = Int(Date().timeIntervalSince1970)
            try await ref.setData(
                [
                    "title": title,
                    "notes": "",
                    "isFavorite": false,
                    "sortOrder": order,
                    "active": true,
                ]
            )
            newTitle = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleFavorite(_ item: ListItem) async {
        guard let householdId else { return }
        errorMessage = nil
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document(item.id)
            try await ref.updateData(["isFavorite": !item.isFavorite])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setActive(_ item: ListItem, active: Bool) async {
        guard let householdId else { return }
        errorMessage = nil
        do {
            let ref = Firestore.firestore()
                .collection("households")
                .document(householdId)
                .collection("listItems")
                .document(item.id)
            try await ref.updateData(["active": active])
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
