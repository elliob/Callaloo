//
//  UserProfile.swift
//  Callaloo
//

import FirebaseFirestore

enum UserRole: String, CaseIterable, Sendable {
    case admin
    case parent
}

struct UserProfile: Equatable, Sendable {
    var householdId: String?
    var role: UserRole?
    var email: String?
    var displayName: String?

    static func from(_ snapshot: DocumentSnapshot) -> UserProfile? {
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        let householdId: String? = {
            guard let raw = data["householdId"] as? String else { return nil }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }()
        let role = (data["role"] as? String).flatMap(UserRole.init(rawValue:))
        return UserProfile(
            householdId: householdId,
            role: role,
            email: data["email"] as? String,
            displayName: data["displayName"] as? String
        )
    }
}
