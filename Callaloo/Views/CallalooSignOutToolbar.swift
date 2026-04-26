//
//  CallalooSignOutToolbar.swift
//  Callaloo
//

import SwiftUI

private struct CallalooSignOutToolbarModifier: ViewModifier {
    @Environment(SessionStore.self) private var session

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        session.signOut()
                    } label: {
                        Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityHint("Signs out of your account on this device")
                }
            }
    }
}

extension View {
    func callalooLogOutButton() -> some View {
        modifier(CallalooSignOutToolbarModifier())
    }
}
