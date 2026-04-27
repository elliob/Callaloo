//
//  SessionStore.swift
//  Callaloo
//

import Foundation
import Observation
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class SessionStore {
    private(set) var user: User?
    private(set) var userProfile: UserProfile?
    var lastErrorMessage: String?

    nonisolated(unsafe) private var authHandle: AuthStateDidChangeListenerHandle?
    nonisolated(unsafe) private var profileListener: ListenerRegistration?

    init() {
        listenAuth()
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
        profileListener?.remove()
    }

    var needsHousehold: Bool {
        guard user != nil else { return false }
        let hid = userProfile?.householdId
        return hid == nil || hid?.isEmpty == true
    }

    var role: UserRole? {
        userProfile?.role
    }

    func clearError() {
        lastErrorMessage = nil
    }

    func signOut() {
        do {
            try AuthActions.signOut()
            user = nil
            userProfile = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func listenAuth() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.bind(user: user)
            }
        }
    }

    private func bind(user: User?) {
        profileListener?.remove()
        profileListener = nil
        self.user = user
        userProfile = nil

        guard let user else {
            return
        }

        let ref = Firestore.firestore().collection("users").document(user.uid)
        Task {
            try? await ref.setData(
                [
                    "email": user.email ?? "",
                    "displayName": user.displayName ?? "",
                ],
                merge: true
            )
        }

        profileListener = ref.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor in
                if let error {
                    self?.lastErrorMessage = error.localizedDescription
                    return
                }
                guard let snapshot else { return }
                self?.userProfile = UserProfile.from(snapshot)
            }
        }
    }
}
