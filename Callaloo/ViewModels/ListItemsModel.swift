//
//  ListItemsModel.swift
//  Callaloo
//

import Foundation
import Observation
import FirebaseFirestore

@Observable
@MainActor
final class ListItemsModel {
    private(set) var items: [ListItem] = []
    /// Populated when the list snapshot listener fails (e.g. rules); writes often fail for the same reason.
    private(set) var lastListenError: String?
    nonisolated(unsafe) private var listener: ListenerRegistration?

    func start(householdId: String) {
        listener?.remove()
        lastListenError = nil
        listener = Firestore.firestore()
            .collection("households")
            .document(householdId)
            .collection("listItems")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error {
                        self.lastListenError = error.localizedDescription
                        self.items = []
                        return
                    }
                    self.lastListenError = nil
                    let mapped = snapshot?.documents.compactMap(ListItem.from) ?? []
                    self.items = mapped
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        items = []
        lastListenError = nil
    }

    deinit {
        listener?.remove()
    }
}
