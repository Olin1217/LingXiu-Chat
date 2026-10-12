import SwiftUI
import UIKit

struct AppRootView: View {
    @State private var isSidebarPresented = false
    @State private var topSafeAreaInset: CGFloat = 0

    private let drawerAnimation = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.86)

    var body: some View {
        GeometryReader { proxy in
            let drawerWidth = min(340, proxy.size.width * 0.84)

            ZStack(alignment: .leading) {
                AppTheme.pageBackground
                    .ignoresSafeArea()

                // The conversation list is the stationary card underneath.
                SidePanelView {
                    closeSidebar()
                }
                .padding(.top, topSafeAreaInset)
                .frame(width: drawerWidth)
                .frame(maxHeight: .infinity)
                .allowsHitTesting(isSidebarPresented)
                .accessibilityHidden(!isSidebarPresented)

                // The complete conversation is the foreground card. Opening the
                // sidebar moves this card as one layer and reveals the list below.
                ZStack {
                    Rectangle()
                        .fill(AppTheme.pageBackground)

                    NavigationStack {
                        AnalysisHomeView {
                            withAnimation(drawerAnimation) {
                                isSidebarPresented.toggle()
                            }
                        }
                    }
                    Rectangle()
                        .fill(AppTheme.deepBlack.opacity(isSidebarPresented ? 0.12 : 0))
                        .contentShape(Rectangle())
                        .allowsHitTesting(isSidebarPresented)
                        .onTapGesture {
                            closeSidebar()
                        }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(AppTheme.pageBackground)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: isSidebarPresented ? 28 : 0,
                        style: .continuous
                    )
                )
                .shadow(
                    color: AppTheme.deepBlack.opacity(isSidebarPresented ? 0.10 : 0),
                    radius: 12,
                    x: -2,
                    y: 0
                )
                .offset(x: isSidebarPresented ? drawerWidth : 0)
                .zIndex(1)
            }
            .animation(drawerAnimation, value: isSidebarPresented)
            .onAppear {
                refreshTopSafeAreaInset()
            }
            .onChange(of: proxy.size) {
                refreshTopSafeAreaInset()
            }
        }
        .ignoresSafeArea()
        .foregroundStyle(AppTheme.primaryText)
        .tint(AppTheme.accent)
    }

    private func closeSidebar() {
        withAnimation(drawerAnimation) {
            isSidebarPresented = false
        }
    }

    private func refreshTopSafeAreaInset() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindowInset = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.top ?? 0
        let statusBarHeight = scenes
            .compactMap { $0.statusBarManager?.statusBarFrame.height }
            .max() ?? 0
        let resolvedInset = max(keyWindowInset, statusBarHeight)
        if topSafeAreaInset != resolvedInset {
            topSafeAreaInset = resolvedInset
        }
    }
}
