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
                ForEach(model.items) { item in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.headline)
                            if !item.notes.isEmpty {
                                Text(item.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button {
                            Task { await toggleFavorite(item) }
                        } label: {
                            Image(systemName: item.isFavorite ? "star.fill" : "star")
                                .foregroundStyle(item.isFavorite ? .yellow : .secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Hide", role: .destructive) {
                            Task { await setActive(item, active: false) }
                        }
                    }
                }
            }
            .navigationTitle("Groceries")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Sign out", role: .destructive) {
                        session.signOut()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 8) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    HStack {
                        TextField("Add an item", text: $newTitle)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            Task { await addItem() }
                        }
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
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
