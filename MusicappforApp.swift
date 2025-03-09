import SwiftUI

@main
struct MusicPlayerApp: App {
    @StateObject private var viewModel = MusicPlayerViewModel()

    init() {
        // Clear UserDefaults on first launch after reinstallation
        if !UserDefaults.standard.bool(forKey: "hasLaunchedBefore") {
            UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
        }
    }

    var body: some Scene {
        WindowGroup {
            MainContentView(viewModel: viewModel)
        }
    }
}
