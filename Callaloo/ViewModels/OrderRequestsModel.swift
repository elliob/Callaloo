//
//  OrderRequestsModel.swift
//  Callaloo
//

import Foundation
import Observation
import FirebaseFirestore

@Observable
@MainActor
final class OrderRequestsModel {
    private(set) var orders: [OrderRequest] = []
    nonisolated(unsafe) private var listener: ListenerRegistration?

    func start(householdId: String) {
        listener?.remove()
        listener = Firestore.firestore()
            .collection("households")
            .document(householdId)
            .collection("orderRequests")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, _ in
                let mapped = snapshot?.documents.compactMap(OrderRequest.from) ?? []
                Task { @MainActor in
                    self?.orders = mapped
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        orders = []
    }

    deinit {
        listener?.remove()
    }
}
