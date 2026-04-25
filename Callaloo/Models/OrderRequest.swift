//
//  OrderRequest.swift
//  Callaloo
//

import FirebaseFirestore

struct OrderRequest: Identifiable, Hashable, Sendable {
    enum Status: String, Sendable {
        case pending
        case ordered
        case cancelled
    }

    var id: String
    var status: Status
    var itemsSnapshot: [[String: String]]
    var createdByParentUid: String
    var createdAt: Date?
    var orderedAt: Date?

    static func from(_ document: DocumentSnapshot) -> OrderRequest? {
        guard document.exists, let data = document.data() else { return nil }
        let statusRaw = data["status"] as? String ?? Status.pending.rawValue
        let status = Status(rawValue: statusRaw) ?? .pending
        let items = data["itemsSnapshot"] as? [[String: String]] ?? []
        let createdBy = data["createdByParentUid"] as? String ?? ""
        return OrderRequest(
            id: document.documentID,
            status: status,
            itemsSnapshot: items,
            createdByParentUid: createdBy,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            orderedAt: (data["orderedAt"] as? Timestamp)?.dateValue()
        )
    }
}
