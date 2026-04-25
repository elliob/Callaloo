//
//  AuthActions.swift
//  Callaloo
//

import UIKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn

enum AuthActions {
    static func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthActionError.missingClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenter = UIApplication.shared.callalooRootViewController() else {
            throw AuthActionError.noPresenter
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthActionError.missingIDToken
        }
        let accessToken = result.user.accessToken.tokenString
        let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
        try await Auth.auth().signIn(with: credential)
    }

    static func signInEmail(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    static func registerEmail(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }
}

enum AuthActionError: LocalizedError {
    case missingClientID
    case noPresenter
    case missingIDToken

    var errorDescription: String? {
        switch self {
        case .missingClientID:
            "Google Sign-In is not configured. Add a valid GoogleService-Info.plist from Firebase."
        case .noPresenter:
            "Could not find a screen to present Google Sign-In."
        case .missingIDToken:
            "Google did not return an ID token."
        }
    }
}
