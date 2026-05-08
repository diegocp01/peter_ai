import SwiftUI

@main
struct PeterAIApp: App {
    @StateObject private var viewModel = PeterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
        }
    }
}
