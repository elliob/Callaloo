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
                VStack(spacing: 20) {
                    Image("CallalooMark")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)
                    ProgressView()
                        .scaleEffect(1.1)
                    Text("Loading your profile…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background {
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.1),
                            Color(.systemGroupedBackground),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea()
                }
            }
        }
    }
}

#Preview {
    RootView()
        .environment(SessionStore())
}
