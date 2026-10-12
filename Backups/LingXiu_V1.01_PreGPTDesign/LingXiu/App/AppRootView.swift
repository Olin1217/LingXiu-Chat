import SwiftUI

struct AppRootView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            Tab("AI 分析", systemImage: "sparkles", value: .analysis) {
                NavigationStack {
                    AnalysisHomeView()
                }
            }

            Tab("角色卡", systemImage: "person.text.rectangle", value: .roleCards) {
                NavigationStack {
                    RoleCardListView()
                }
            }
        }
        .tint(Color("AccentColor"))
    }
}
