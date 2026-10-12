import SwiftUI

@main
struct LingXiuApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(store)
        }
    }
}
