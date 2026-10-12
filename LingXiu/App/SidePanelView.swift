import Foundation
import SwiftUI

/// The compact points badge follows the Figma asset: a yellow coin with the
/// white bone mark. Keeping it as an asset instead of redrawing the vector
/// preserves the exact proportions at every Dynamic Type size.
struct PointsBoneIcon: View {
    var size: CGFloat = 26

    var body: some View {
        Image("PointsBone")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

func lingXiuPointsText(_ points: Int) -> String {
    let clamped = min(max(points, 0), 99_999)
    guard clamped >= 1_000 else { return String(clamped) }
    return "\(clamped / 1_000),\(String(format: "%03d", clamped % 1_000))"
}

struct SidePanelView: View {
    @Environment(AppStore.self) private var store
    @State private var showRoleCards = false
    @State private var showSearch = false
    @State private var showAccount = false
    @State private var showPoints = false
    @State private var closeSidebarAfterSearch = false
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Button {
                        // “新分析” starts a new chat surface while keeping
                        // completed analyses in the Recent list.
                        store.beginNewConversation()
                        close()
                    } label: {
                        Label("新分析", systemImage: "square.and.pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 46)
                            .background(AppTheme.accent, in: Capsule())
                            .foregroundStyle(AppTheme.pureWhite)
                    }
                    .buttonStyle(.plain)

                    SidePanelSectionTitle("沟通对象")

                    VStack(spacing: 0) {
                        if store.roleCards.isEmpty {
                            Button {
                                showRoleCards = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus")
                                        .font(.body.weight(.medium))
                                        .frame(width: 24)
                                        .accessibilityHidden(true)

                                    Text("创建沟通角色卡")
                                        .font(.body)

                                    Spacer(minLength: 0)
                                }
                                .foregroundStyle(AppTheme.primaryText)
                                .padding(.horizontal, 16)
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("创建沟通角色卡")
                        } else {
                            ForEach(Array(store.roleCards.enumerated()), id: \.element.id) { index, card in
                                Button {
                                    store.selectRoleCard(id: card.id)
                                    close()
                                } label: {
                                    HStack(spacing: 12) {
                                        RoleAvatarView(card: card, size: 42)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name)
                                                .font(.body)
                                                .foregroundStyle(AppTheme.primaryText)
                                                .lineLimit(1)
                                            Text(card.relationship)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                                .lineLimit(1)
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                    .background(
                                        store.selectedRoleCard?.id == card.id ? AppTheme.subtleFill : Color.clear
                                    )
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < store.roleCards.count - 1 {
                                    Divider()
                                        .padding(.leading, 66)
                                }
                            }
                        }
                    }
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Button {
                        showRoleCards = true
                    } label: {
                        Label("管理角色卡", systemImage: "slider.horizontal.3")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if !store.exchanges.isEmpty {
                        SidePanelSectionTitle("最近")

                        VStack(spacing: 0) {
                            ForEach(Array(store.exchanges.reversed().enumerated()), id: \.element.id) { index, exchange in
                                Button {
                                    store.restoreDraft(from: exchange)
                                    close()
                                } label: {
                                    Text(recentTitle(for: exchange))
                                        .font(.body)
                                        .foregroundStyle(AppTheme.primaryText)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .background(
                                            store.selectedExchangeID == exchange.id ? AppTheme.subtleFill : Color.clear
                                        )
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if index < store.exchanges.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 12)
                                }
                            }
                        }
                        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 28)
            }
        }
        .background(AppTheme.pageBackground)
        .sheet(isPresented: $showRoleCards) {
            RoleCardSelectionView(
                roleSelection: Binding(
                    get: { store.draft.selectedRoleCardID },
                    set: { store.selectRoleCard(id: $0) }
                ),
                identitySelection: Binding(
                    get: { store.draft.selectedIdentityCardID },
                    set: { store.selectIdentityCard(id: $0) }
                )
            )
        }
        .sheet(isPresented: $showAccount) {
            AccountCenterView()
        }
        .sheet(isPresented: $showPoints) {
            NavigationStack {
                PointsPurchaseView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showPoints = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("关闭积分页面")
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showSearch, onDismiss: {
            if closeSidebarAfterSearch {
                closeSidebarAfterSearch = false
                close()
            }
        }) {
            SidePanelSearchView(
                onSelectRoleCard: { card in
                    store.selectRoleCard(id: card.id)
                    closeSidebarAfterSearch = true
                },
                onSelectIdentityCard: { card in
                    store.selectIdentityCard(id: card.id)
                    closeSidebarAfterSearch = true
                },
                onSelectExchange: { exchange in
                    store.restoreDraft(from: exchange)
                    closeSidebarAfterSearch = true
                }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                showAccount = true
            } label: {
                HStack(spacing: 10) {
                    UserAvatarView(profile: store.userProfile, size: 42)

                    Text(store.userProfile.displayName)
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .truncationMode(.tail)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            // Keep the trailing points/search controls stable when a user has
            // a long display name. The name is the flexible region; it must
            // never push a control outside the safe area.
            .layoutPriority(0)
            .accessibilityLabel("用户：\(store.userProfile.displayName)，打开个人中心")

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Button {
                    showPoints = true
                } label: {
                    HStack(spacing: 4) {
                        // The Figma badge keeps the coin visually tucked into
                        // the capsule's leading edge. Offset only the icon so
                        // the badge width and the number's alignment stay
                        // unchanged.
                        PointsBoneIcon(size: 26)
                            .offset(x: -4)
                        Text(lingXiuPointsText(store.userProfile.points))
                            .monospacedDigit()
                    }
                    .font(.subheadline.weight(.semibold))
                    // Keep the number optically away from the capsule edge;
                    // the right inset is intentionally a little wider than
                    // the icon side, matching the Figma badge.
                    .padding(.leading, 6)
                    .padding(.trailing, 12)
                    .frame(minHeight: 32)
                    .background(AppTheme.subtleFill, in: Capsule())
                }
                .buttonStyle(.plain)
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("积分 \(store.userProfile.points)，购买积分")

                Button {
                    showSearch = true
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.medium))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .accessibilityLabel("搜索聊天和角色卡")
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    private func recentTitle(for exchange: AnalysisExchange) -> String {
        let text = exchange.draft.conversationText
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { return text }
        if let quickTopic = exchange.draft.quickTopic { return quickTopic.rawValue }
        return exchange.result.summary
    }
}

private struct SidePanelSearchView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var appliedSearchText = ""
    @FocusState private var searchFocused: Bool

    let onSelectRoleCard: (ChatRoleCard) -> Void
    let onSelectIdentityCard: (IdentityCard) -> Void
    let onSelectExchange: (AnalysisExchange) -> Void

    private var normalizedSearchText: String {
        appliedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredRoleCards: [ChatRoleCard] {
        guard !normalizedSearchText.isEmpty else { return [] }
        return store.roleCards.filter { card in
            [card.name, card.relationship, card.identity, card.userDescription, card.speakingStyle, card.notes]
                .contains { $0.localizedCaseInsensitiveContains(normalizedSearchText) }
        }
    }

    private var filteredIdentityCards: [IdentityCard] {
        guard !normalizedSearchText.isEmpty else { return [] }
        return store.identityCards.filter { card in
            [card.name, card.identity, card.userDescription, card.speakingStyle, card.notes]
                .contains { $0.localizedCaseInsensitiveContains(normalizedSearchText) }
        }
    }

    private var filteredExchanges: [AnalysisExchange] {
        guard !normalizedSearchText.isEmpty else { return [] }
        return store.exchanges.filter { exchange in
            let replyText = exchange.replies.map(\.text).joined(separator: " ")
            let roleName = store.roleCards.first { $0.id == exchange.draft.selectedRoleCardID }?.name ?? ""
            let identityName = store.identityCards.first { $0.id == exchange.draft.selectedIdentityCardID }?.name ?? ""
            let quickTopic = exchange.draft.quickTopic?.rawValue ?? ""
            return [exchange.draft.conversationText, exchange.result.summary, replyText, roleName, identityName, quickTopic]
                .contains { $0.localizedCaseInsensitiveContains(normalizedSearchText) }
        }
    }

    private var hasResults: Bool {
        !filteredRoleCards.isEmpty || !filteredIdentityCards.isEmpty || !filteredExchanges.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Keep one stable list in the hierarchy while the query
                // changes. Replacing ContentUnavailableView with List after
                // the first character would recreate the navigation content,
                // resign the TextField and dismiss the keyboard.
                List {
                    if !filteredExchanges.isEmpty {
                        Section("最近") {
                            ForEach(filteredExchanges.reversed()) { exchange in
                                Button {
                                    completeSelection {
                                        onSelectExchange(exchange)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(exchange.draft.conversationText)
                                            .foregroundStyle(AppTheme.primaryText)
                                            .lineLimit(2)
                                        Text(exchange.result.summary)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.secondaryText)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }

                    if !filteredRoleCards.isEmpty {
                        Section("沟通对象") {
                            ForEach(filteredRoleCards) { card in
                                Button {
                                    completeSelection {
                                        onSelectRoleCard(card)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        RoleAvatarView(card: card, size: 42)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name).foregroundStyle(AppTheme.primaryText)
                                            Text([card.relationship, card.identity].filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !filteredIdentityCards.isEmpty {
                        Section("我的身份卡") {
                            ForEach(filteredIdentityCards) { card in
                                Button {
                                    completeSelection {
                                        onSelectIdentityCard(card)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        IdentityAvatarView(card: card, size: 42)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(card.name).foregroundStyle(AppTheme.primaryText)
                                            Text(card.identity.isEmpty ? "我的身份" : card.identity)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.secondaryText)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AppTheme.groupedBackground)
                .scrollDismissesKeyboard(.interactively)
                .opacity(hasResults ? 1 : 0)
                .allowsHitTesting(hasResults)

                if normalizedSearchText.isEmpty {
                    ContentUnavailableView(
                        "搜索聊天和角色卡",
                        systemImage: "magnifyingglass",
                        description: Text("输入关键词，查找最近分析、沟通角色卡和我的身份卡。")
                    )
                } else if !hasResults {
                    ContentUnavailableView {
                        Label("没有找到相关结果", systemImage: "magnifyingglass")
                    } description: {
                        Text("检查拼写或尝试搜索其他关键词。")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.groupedBackground)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 8) {
                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.secondaryText)
                        TextField("搜索", text: $searchText)
                            .focused($searchFocused)
                            .submitLabel(.search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("searchField")
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 54)
                    .background(.regularMaterial, in: Capsule())

                    Button {
                        // Dismiss the full-screen cover through SwiftUI's
                        // presentation environment. Mutating the parent's
                        // `showSearch` binding from inside the presented view
                        // can race the cover teardown on iOS 26 and, in the
                        // previous implementation, occasionally terminated
                        // the app instead of merely closing search.
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.large)
                    .tint(AppTheme.primaryText)
                    .accessibilityLabel("关闭搜索")
                    .accessibilityIdentifier("closeSearchButton")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(AppTheme.groupedBackground.ignoresSafeArea(edges: .bottom))
            }
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .task { @MainActor in
            // Request focus once after the cover has attached its text field.
            // The task is automatically cancelled when the cover disappears,
            // so it cannot mutate FocusState after the close transition.
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            searchFocused = true
        }
        .task(id: searchText) { @MainActor in
            // Debounce local filtering so every keystroke stays responsive
            // even when the conversation history contains long replies.
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            appliedSearchText = searchText
        }
    }

    private func completeSelection(_ action: @escaping @MainActor () -> Void) {
        action()
        dismiss()
    }
}

private struct SidePanelSectionTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.title3.weight(.bold))
            .foregroundStyle(AppTheme.primaryText)
    }
}
