//
//  CallalooApp.swift
//  Callaloo
//

import SwiftUI
import FirebaseCore

@main
struct CallalooApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var session: SessionStore

    init() {
        FirebaseApp.configure()
        _session = State(wrappedValue: SessionStore())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
    }
}
