//
//  RootView.swift
//  Callaloo
//

import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.user == nil {
                LoginView()
            } else if session.needsHousehold {
                HouseholdOnboardingView()
            } else if session.role == .admin {
                AdminMainTabView()
            } else if session.role == .parent {
                ParentMainView()
            } else {
                ProgressView("Loading your profile…")
                    .padding()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(SessionStore())
}
