import SwiftUI

struct AppRootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView {
                    withAnimation(.smooth) {
                        hasCompletedOnboarding = true
                    }
                }
            }
        }
        .tint(Color("AccentColor"))
    }
}

struct MainTabView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        TabView(selection: $store.selectedTab) {
            Tab("分析", systemImage: "sparkles", value: .analysis) {
                NavigationStack(path: $store.analysisPath) {
                    AnalysisHomeView()
                        .navigationDestination(for: AnalysisRoute.self) { route in
                            AnalysisRouteView(route: route)
                        }
                }
            }

            Tab("人物", systemImage: "person.2.fill", value: .people) {
                NavigationStack {
                    PeopleListView()
                }
            }

            Tab("记录", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90", value: .records) {
                NavigationStack {
                    RecordsListView()
                }
            }

            Tab("我的", systemImage: "person.crop.circle", value: .profile) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
    }
}

private struct AnalysisRouteView: View {
    let route: AnalysisRoute

    var body: some View {
        switch route {
        case let .newAnalysis(mode, scene):
            NewAnalysisView(initialMode: mode, scene: scene)
        case .supplement:
            ContextSupplementView()
        case .analyzing:
            AnalysisProgressView()
        case .result:
            AnalysisResultView()
        case .goals:
            ResponseGoalView()
        case .replyStyle:
            ReplyStyleView()
        case .replies:
            ReplyOptionsView()
        case let .editReply(id):
            EditReplyView(replyID: id)
        }
    }
}
