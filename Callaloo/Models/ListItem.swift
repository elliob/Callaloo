//
//  ListItem.swift
//  Callaloo
//

import FirebaseFirestore

struct ListItem: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var notes: String
    var isFavorite: Bool
    var sortOrder: Int
    var active: Bool

    static func from(_ document: DocumentSnapshot) -> ListItem? {
        guard document.exists, let data = document.data() else { return nil }
        guard let title = data["title"] as? String else { return nil }
        return ListItem(
            id: document.documentID,
            title: title,
            notes: data["notes"] as? String ?? "",
            isFavorite: data["isFavorite"] as? Bool ?? false,
            sortOrder: data["sortOrder"] as? Int ?? 0,
            active: data["active"] as? Bool ?? true
        )
    }

    func asFirestoreData() -> [String: Any] {
        [
            "title": title,
            "notes": notes,
            "isFavorite": isFavorite,
            "sortOrder": sortOrder,
            "active": active,
        ]
    }
}
