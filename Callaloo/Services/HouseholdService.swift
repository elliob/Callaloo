//
//  HouseholdService.swift
//  Callaloo
//

import Foundation
import FirebaseFunctions

enum HouseholdService {
    private static let functions = Functions.functions(region: "us-central1")

    /// Maps Firebase Callable errors to clearer copy. A bare **"NOT FOUND"** is HTTP 404 on the
    /// function URL (e.g. `createHousehold` not deployed), not the invite “not found” case (that
    /// includes the server message from `HttpsError`).
    static func userFacingMessage(forCallableError error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: ns.code)
        else {
            return error.localizedDescription
        }
        let description = ns.localizedDescription
        switch code {
        case .notFound:
            if description == "NOT FOUND" {
                return "Couldn’t reach the family service. Deploy Cloud Functions to this Firebase project (README: Backend setup), then try again."
            }
            return description
        case .unimplemented:
            if description == "UNIMPLEMENTED" {
                return "That server feature isn’t available. Deploy the latest Cloud Functions, then try again."
            }
            return description
        case .unavailable:
            return "The service is temporarily unavailable. Try again in a moment."
        default:
            return description
        }
    }

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
