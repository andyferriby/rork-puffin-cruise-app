//
//  PuffinCruisesAmbleApp.swift
//  PuffinCruisesAmble
//

import SwiftUI

@main
struct PuffinCruisesAmbleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .task { await PushRegistration.requestAuthorizationAndRegister() }
        }
    }
}
