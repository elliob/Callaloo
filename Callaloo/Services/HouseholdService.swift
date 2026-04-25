//
//  HouseholdService.swift
//  Callaloo
//

import Foundation
import FirebaseFunctions

enum HouseholdService {
    private static let functions = Functions.functions(region: "us-central1")

    static func createHousehold(displayName: String) async throws -> String {
        let result = try await functions.httpsCallable("createHousehold").call(["displayName": displayName])
        guard let dict = result.data as? [String: Any],
              let householdId = dict["householdId"] as? String
        else {
            throw HouseholdServiceError.invalidResponse
        }
        return householdId
    }

    static func createParentInvite(householdId: String) async throws -> String {
        let result = try await functions.httpsCallable("createParentInvite").call(["householdId": householdId])
        guard let dict = result.data as? [String: Any],
              let inviteId = dict["inviteId"] as? String
        else {
            throw HouseholdServiceError.invalidResponse
        }
        return inviteId
    }

    static func redeemParentInvite(inviteId: String) async throws -> String {
        let trimmed = inviteId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HouseholdServiceError.invalidInvite }
        let result = try await functions.httpsCallable("redeemParentInvite").call(["inviteId": trimmed])
        guard let dict = result.data as? [String: Any],
              let householdId = dict["householdId"] as? String
        else {
            throw HouseholdServiceError.invalidResponse
        }
        return householdId
    }
}

enum HouseholdServiceError: LocalizedError {
    case invalidResponse
    case invalidInvite

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Unexpected response from server. Deploy Cloud Functions and try again."
        case .invalidInvite:
            "Enter the invite code your family admin shared with you."
        }
    }
}
