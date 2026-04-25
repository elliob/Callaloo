//
//  CallalooApp.swift
//  Callaloo
//

import SwiftUI
import FirebaseCore

@main
struct CallalooApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session = SessionStore()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
