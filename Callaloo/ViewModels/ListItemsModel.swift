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
    nonisolated(unsafe) private var listener: ListenerRegistration?

    func start(householdId: String) {
        listener?.remove()
        listener = Firestore.firestore()
            .collection("households")
            .document(householdId)
            .collection("listItems")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, _ in
                let mapped = snapshot?.documents.compactMap(ListItem.from) ?? []
                Task { @MainActor in
                    self?.items = mapped
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        items = []
    }

    deinit {
        listener?.remove()
    }
}
