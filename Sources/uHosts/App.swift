import SwiftUI

@main
struct UHostsApp: App {
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Image(systemName: "network")
        }
        .menuBarExtraStyle(.window)
    }
}
