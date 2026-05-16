import SwiftUI

@main
struct PeterAIWatchApp: App {
    @StateObject private var viewModel = WatchPeterViewModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(viewModel)
        }
    }
}
