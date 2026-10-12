import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AnalysisHomeView: View {
    @Environment(AppStore.self) private var store
    let onOpenMenu: () -> Void
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isRecognizing = false
    @State private var importError: String?
    @State private var showPhotoPicker = false
    @State private var showCameraPicker = false
    @State private var showFileImporter = false
    @State private var showAttachmentOptions = false
    @State private var showRoleCards = false
    @State private var showPrivacyInfo = false
    @State private var showClearConfirmation = false
    @State private var showPointsPurchase = false
    @State private var copiedItemID: UUID?
    @State private var regeneratingExchangeID: UUID?
    @State private var composerFocused = false
    @State private var composerSelection = NSRange(location: 0, length: 0)
    @State private var composerMetrics = ComposerTextMetrics()
    @State private var composerCardWidth: CGFloat = 369
    @State private var isComposerExpanded = false
    @State private var submitAfterComposerDismissal = false

    init(onOpenMenu: @escaping () -> Void = {}) {
        self.onOpenMenu = onOpenMenu
    }

    var body: some View {
        @Bindable var store = store

        conversationScroller
        .accessibilityHidden(isComposerExpanded)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !isComposerExpanded {
                composer(
                    text: $store.draft.conversationText,
                    optimizationQuote: $store.draft.optimizationQuote
                )
            }
        }
        .navigationTitle("沟通分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    openMenu()
                } label: {
                    Image(systemName: "equal")
                }
                .accessibilityLabel("更多")
            }

            ToolbarItem(placement: .principal) {
                Button {
                    openRoleCards()
                } label: {
                    Text(store.selectedRoleCard.map { "沟通分析 · \($0.name)" } ?? "沟通分析")
                        .font(.headline)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择沟通对象和我的身份")
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    openRoleCards()
                } label: {
                    RoleAvatarView(card: store.selectedRoleCard, size: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.selectedRoleCard == nil ? "选择角色卡" : "角色卡：\(store.selectedRoleCard?.name ?? "")")

                Menu {
                    Button {
                        startNewAnalysis()
                    } label: {
                        Label("新分析", systemImage: "square.and.pencil")
                    }

                    Button {
                        showPrivacyInfo = true
                    } label: {
                        Label("隐私与分析说明", systemImage: "hand.raised")
                    }

                    if !store.currentExchanges.isEmpty {
                        Button(role: .destructive) {
                            showClearConfirmation = true
                        } label: {
                            Label("清空当前对话", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .confirmationDialog("清空当前聊天内容？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                            Button("清空", role: .destructive) {
                                clearCurrentConversation()
                            }
                            Button("取消", role: .cancel) { }
                        } message: {
                            Text("当前聊天内容会被清空，已保存的角色卡不会受影响。")
                        }
                }
                .accessibilityLabel("更多")
            }
        }
        .preservesBackgroundLayoutWhileKeyboardPresented(showRoleCards)
        .fullScreenCover(isPresented: $isComposerExpanded, onDismiss: composerDidDismiss) {
            ExpandedComposerView(
                text: $store.draft.conversationText,
                selection: $composerSelection,
                placeholder: composerPlaceholder(optimizationQuote: store.draft.optimizationQuote),
                quickTopic: store.draft.quickTopic,
                canSubmit: canSubmit,
                isAnalyzing: store.isAnalyzing,
                onDeleteToken: quickTopicDeleteAction,
                onMetricsChange: { _ in },
                onCollapse: collapseComposer,
                onSubmit: submit
            )
            .interactiveDismissDisabled()
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItems,
            maxSelectionCount: 3,
            matching: .images
        )
        .sheet(isPresented: $showCameraPicker) {
            CameraPicker(
                onCapture: { data in
                    Task { await importImageData([data]) }
                },
                onDismiss: {
                    showCameraPicker = false
                }
            )
            .ignoresSafeArea()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            loadFiles(result)
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await loadPhotos(newItems) }
        }
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
        .alert("隐私与分析说明", isPresented: $showPrivacyInfo) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text(store.isRemoteAIConfigured
                ? (store.remoteAIUsesServerProxy
                    ? "当前已配置灵嗅云端分析服务。你提交的文字和图片会经灵嗅服务器发送给模型处理，响应已设置为不在方舟存储。AI 只能根据你提供的信息给出可能性，不能确定他人的真实心理。上传前请遮挡姓名、头像、账号等敏感信息。"
                    : "当前已配置火山方舟 Doubao-Seed-Evolving 开发测试连接。你提交的文字和图片会直接发送给模型处理，响应已设置为不在方舟存储。AI 只能根据你提供的信息给出可能性，不能确定他人的真实心理。上传前请遮挡姓名、头像、账号等敏感信息。")
                : "当前使用设备本地演示分析，尚未配置火山方舟 API。AI 只能根据你提供的信息给出可能性，不能确定他人的真实心理。上传前请遮挡姓名、头像、账号等敏感信息。")
        }
        .alert("云端分析暂不可用", isPresented: Binding(
            get: { store.analysisServiceNotice != nil },
            set: { if !$0 { store.analysisServiceNotice = nil } }
        )) {
            Button("知道了", role: .cancel) {
                store.analysisServiceNotice = nil
            }
        } message: {
            Text(store.analysisServiceNotice ?? "本次已使用设备本地分析。")
        }
        .alert("图片处理提示", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("知道了", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "请重新选择图片。")
        }
        .alert("积分不足", isPresented: Binding(
            get: { store.pointErrorMessage != nil },
            set: { if !$0 { store.pointErrorMessage = nil } }
        )) {
            Button("购买积分") {
                store.pointErrorMessage = nil
                showPointsPurchase = true
            }
            Button("取消", role: .cancel) {
                store.pointErrorMessage = nil
            }
        } message: {
            Text(store.pointErrorMessage ?? "请先购买积分后再进行沟通分析。")
        }
        .sheet(isPresented: $showPointsPurchase) {
            NavigationStack {
                PointsPurchaseView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                showPointsPurchase = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .accessibilityLabel("关闭积分页面")
                        }
                    }
            }
        }
    }

    private func openMenu() {
        dismissComposerKeyboard()
        DispatchQueue.main.async {
            onOpenMenu()
        }
    }

    private func startNewAnalysis() {
        selectedPhotoItems = []
        importError = nil
        store.beginNewConversation()
        composerSelection = NSRange(location: 0, length: 0)
        composerFocused = true
    }

    private func clearCurrentConversation() {
        selectedPhotoItems = []
        importError = nil
        store.clearConversation()
        composerSelection = NSRange(location: 0, length: 0)
        composerFocused = false
    }

    private func openRoleCards() {
        guard !showRoleCards else { return }
        dismissComposerKeyboard()

        // Finish resigning the custom text view before the sheet transition.
        // Presenting both changes in one update cycle can create a SwiftUI graph loop.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            showRoleCards = true
        }
    }

    private func dismissComposerKeyboard() {
        composerFocused = false
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private var conversationScroller: some View {
        ScrollViewReader { proxy in
            ScrollView {
                conversationContent
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollEdgeEffectStyle(nil, for: .bottom)
            .background(AppTheme.pageBackground)
            .dismissesKeyboardOnBackgroundTap()
            .onChange(of: store.exchanges.count) {
                scrollToBottom(using: proxy)
            }
            .onChange(of: store.isAnalyzing) {
                scrollToBottom(using: proxy)
            }
        }
    }

    private var conversationContent: some View {
        LazyVStack(alignment: .leading, spacing: 28) {
            ForEach(store.currentExchanges) { exchange in
                exchangeView(exchange)
                    .id(exchange.id)
            }

            if let pendingDraft = store.pendingDraft {
                pendingAnalysisView(pendingDraft)
            }

            Color.clear
                .frame(height: 1)
                .id("conversation-bottom")
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity)
    }

    private func exchangeView(_ exchange: AnalysisExchange) -> some View {
        ConversationExchangeView(
            exchange: exchange,
            roleCard: roleCard(for: exchange.draft),
            copiedItemID: $copiedItemID,
            isRegenerating: regeneratingExchangeID == exchange.id,
            onCopy: copy,
            onOptimize: { quotedText in
                store.beginOptimization(for: quotedText)
                composerFocused = true
            },
            onRegenerate: {
                regenerate(exchange)
            }
        )
    }

    private func pendingAnalysisView(_ draft: AnalysisDraft) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            UserMessageView(
                draft: draft,
                roleCard: roleCard(for: draft)
            )

            ThinkingIndicatorView()
                .padding(.leading, 4)
            .transition(.opacity)
        }
    }

    private func composer(text: Binding<String>, optimizationQuote: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !store.draft.imageData.isEmpty {
                SelectedImageStrip(imageData: store.draft.imageData) {
                    selectedPhotoItems = []
                    store.draft.imageData = []
                    importError = nil
                }
                .padding(.horizontal, 6)
                // Keep the attachment thumbnails visually separated from the
                // composer without adding a secondary OCR status line. The
                // result is closer to the GPT-style attachment treatment in
                // the reference and avoids pushing the editor upward.
                .padding(.top, 5)
            }

            if let quote = optimizationQuote.wrappedValue {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "quote.opening")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("优化这段回复")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                        Text(quote)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 36)
                }
                .overlay(alignment: .topTrailing) {
                    Button {
                        optimizationQuote.wrappedValue = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .frame(width: 44, height: 44, alignment: .topTrailing)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(AppTheme.secondaryText)
                    .accessibilityLabel("取消优化引用")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if !store.isAnalyzing && !composerFocused {
                quickTopicStrip
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            composerCard(
                text: text,
                optimizationQuote: optimizationQuote.wrappedValue
            )
        }
        .frame(maxWidth: 720)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity)
        .background(AppTheme.pageBackground.ignoresSafeArea(edges: .bottom))
    }

    private func composerCard(text: Binding<String>, optimizationQuote: String?) -> some View {
        let requiresMultiline = ComposerLayoutPolicy.requiresMultiline(
            text: text.wrappedValue,
            compactWidth: composerFocused ? focusedEditorWidth : compactEditorWidth
        )
        let usesExpandedCard = ComposerLayoutPolicy.usesExpandedCard(
            isFocused: composerFocused,
            text: text.wrappedValue,
            compactWidth: composerFocused ? focusedEditorWidth : compactEditorWidth
        )
        let showsExpansion = requiresMultiline && ComposerLayoutPolicy.showsExpansionControl(for: composerMetrics)
        let isCompact = !usesExpandedCard
        let editorLayout: ComposerInputLayout = isCompact ? .compact : .multiline
        let editorLeadingPadding: CGFloat = {
            if isCompact {
                return 46 + selectedQuickTopicWidth + selectedQuickTopicSpacing
            }
            return 16
        }()
        let editorTrailingPadding: CGFloat = {
            if isCompact { return 50 }
            if showsExpansion { return 52 }
            return 16
        }()
        let editorTopPadding: CGFloat = {
            if isCompact { return 0 }
            return 14
        }()
        let editorBottomPadding: CGFloat = isCompact ? 0 : 58
        let cardMinimumHeight: CGFloat = isCompact ? 58 : 0
        let topicAlignment: Alignment = isCompact ? .leading : .topLeading
        let inlineTokenSize: CGSize? = {
            guard !isCompact, store.draft.quickTopic != nil else { return nil }
            return CGSize(
                width: selectedQuickTopicWidth + selectedQuickTopicSpacing,
                // Only the first line should flow around the topic. Keeping
                // this exactly one body-text line tall lets line two return
                // to the composer's natural leading edge.
                height: ComposerLayoutPolicy.inlineTokenHeight()
            )
        }()

        return ComposerTextInput(
            text: text,
            isFocused: mainComposerFocusBinding,
            selection: $composerSelection,
            placeholder: composerPlaceholder(optimizationQuote: optimizationQuote),
            layout: editorLayout,
            onSubmit: submit,
            onDeleteToken: quickTopicDeleteAction,
            onMetricsChange: { composerMetrics = $0 },
            inlineTokenSize: inlineTokenSize
        )
        // Keep this single representable alive while the card changes from
        // compact to GPT-style two-row or multiline layouts. Replacing it in
        // conditional branches makes UIKit resign first responder after the
        // first typed character, which dismisses the keyboard mid-entry.
        .padding(.leading, editorLeadingPadding)
        .padding(.trailing, editorTrailingPadding)
        .padding(.top, editorTopPadding)
        .padding(.bottom, editorBottomPadding)
        .frame(minHeight: cardMinimumHeight, alignment: .top)
        .composerSurface()
        .overlay(alignment: .bottom) {
            HStack(alignment: .center, spacing: 0) {
                attachmentButton
                Spacer(minLength: 0)
                sendButton
            }
            .padding(.horizontal, 10)
            .padding(.bottom, isCompact ? 9 : 8)
        }
        .overlay(alignment: topicAlignment) {
            if let quickTopic = store.draft.quickTopic {
                quickTopicToken(quickTopic)
                    .padding(.leading, isCompact ? 46 : 16)
                    .padding(.top, isCompact ? 0 : editorTopPadding)
            }
        }
        .overlay(alignment: .topTrailing) {
            if showsExpansion {
                Button {
                    expandComposer()
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .padding(.trailing, 2)
                .accessibilityLabel("展开输入框")
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            composerCardWidth = newWidth
        }
        .animation(.snappy(duration: 0.24), value: usesExpandedCard)
        .animation(.snappy(duration: 0.24), value: requiresMultiline)
        .animation(.snappy(duration: 0.24), value: store.draft.quickTopic)
    }

    private var attachmentButton: some View {
        Button {
            showAttachmentOptions = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.regular))
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.primaryText)
        .accessibilityLabel("添加聊天内容")
        .popover(isPresented: $showAttachmentOptions, attachmentAnchor: .point(.top), arrowEdge: .bottom) {
            AttachmentOptionsView(
                hasSelectedImages: !store.draft.imageData.isEmpty,
                onCamera: {
                    showAttachmentOptions = false
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        showCameraPicker = true
                    } else {
                        showPhotoPicker = true
                    }
                },
                onPhotos: {
                    showAttachmentOptions = false
                    showPhotoPicker = true
                },
                onFiles: {
                    showAttachmentOptions = false
                    showFileImporter = true
                },
                onRemoveImages: {
                    selectedPhotoItems = []
                    store.draft.imageData = []
                    importError = nil
                    showAttachmentOptions = false
                }
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    private var sendButton: some View {
        Button {
            if store.isAnalyzing {
                store.cancelAnalysis()
            } else {
                submit()
            }
        } label: {
            Image(systemName: store.isAnalyzing ? "stop.fill" : "arrow.up")
                .font(.body.weight(.bold))
                .foregroundStyle((canSubmit || store.isAnalyzing) ? AppTheme.pureWhite : AppTheme.secondaryText)
                .frame(width: 40, height: 40)
                .background((canSubmit || store.isAnalyzing) ? AppTheme.accent : AppTheme.subtleFill, in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit && !store.isAnalyzing)
        .accessibilityLabel(store.isAnalyzing ? "停止分析" : "开始分析")
    }

    private func quickTopicToken(_ quickTopic: QuickTopic) -> some View {
        Button {
            removeQuickTopic()
        } label: {
            Text(quickTopic.rawValue)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .frame(height: ComposerLayoutPolicy.inlineTokenHeight())
                .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.deepBlack.opacity(0.14), lineWidth: 1)
                }
                .foregroundStyle(AppTheme.pureWhite)
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .accessibilityLabel("移除快捷主题：\(quickTopic.rawValue)")
        .accessibilityHint("移除后可以重新选择沟通主题")
    }

    private var compactEditorWidth: CGFloat {
        // Mirrors the compact HStack: 20 points of horizontal inset, a
        // 36-point attachment button, a 40-point send button, and the token.
        max(composerCardWidth - 96 - selectedQuickTopicWidth - selectedQuickTopicSpacing, 44)
    }

    private var focusedEditorWidth: CGFloat {
        max(composerCardWidth - 32 - selectedQuickTopicWidth - selectedQuickTopicSpacing, 44)
    }

    private var selectedQuickTopicSpacing: CGFloat {
        store.draft.quickTopic == nil ? 0 : 8
    }

    private var selectedQuickTopicWidth: CGFloat {
        guard let title = store.draft.quickTopic?.rawValue else { return 0 }
        let font = UIFont.preferredFont(forTextStyle: .subheadline)
        let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
        return ceil(textWidth) + 20
    }

    private var mainComposerFocusBinding: Binding<Bool> {
        Binding(
            get: { composerFocused && !isComposerExpanded },
            set: { newValue in
                if newValue {
                    composerFocused = true
                } else if !isComposerExpanded {
                    composerFocused = false
                }
            }
        )
    }

    private var quickTopicStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(QuickTopic.allCases) { topic in
                    Button {
                        selectQuickTopic(topic)
                    } label: {
                        Text(topic.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.primaryText)
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("快捷主题：\(topic.rawValue)")
                    .accessibilityHint("选中后输入具体沟通内容")
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollClipDisabled()
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
    }

    private func selectQuickTopic(_ topic: QuickTopic) {
        withAnimation(.snappy(duration: 0.25)) {
            store.selectQuickTopic(topic)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        composerFocused = true
    }

    private func removeQuickTopic() {
        withAnimation(.snappy(duration: 0.25)) {
            store.selectQuickTopic(nil)
        }
        UISelectionFeedbackGenerator().selectionChanged()
        composerFocused = true
    }

    private func expandComposer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        composerFocused = true
        withAnimation(.snappy(duration: 0.28, extraBounce: 0.02)) {
            isComposerExpanded = true
        }
    }

    private func collapseComposer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.snappy(duration: 0.28, extraBounce: 0.02)) {
            isComposerExpanded = false
        }
    }

    private var quickTopicDeleteAction: (() -> Void)? {
        guard store.draft.quickTopic != nil else { return nil }
        return { removeQuickTopic() }
    }

    private func composerPlaceholder(optimizationQuote: String?) -> String {
        if optimizationQuote != nil { return "输入优化方向" }
        if store.draft.quickTopic != nil { return "" }
        if store.isAnalyzing { return "询问灵嗅" }
        return "粘贴聊天内容或描述场景"
    }

    private var canSubmit: Bool {
        store.draft.hasUsableText && !store.isAnalyzing && !isRecognizing
    }

    private func submit() {
        guard canSubmit else { return }
        if isComposerExpanded {
            submitAfterComposerDismissal = true
            composerFocused = false
            withAnimation(.snappy(duration: 0.24, extraBounce: 0)) {
                isComposerExpanded = false
            }
            return
        }

        performSubmit()
    }

    private func composerDidDismiss() {
        guard submitAfterComposerDismissal else { return }
        submitAfterComposerDismissal = false
        performSubmit()
    }

    private func performSubmit() {
        composerFocused = false
        importError = nil
        selectedPhotoItems = []
        Task {
            _ = await store.runAnalysis()
            composerSelection = NSRange(location: 0, length: 0)
        }
    }

    private func roleCard(for draft: AnalysisDraft) -> ChatRoleCard? {
        guard let id = draft.selectedRoleCardID else { return nil }
        return store.roleCards.first { $0.id == id }
    }

    private func copy(_ id: UUID, text: String) {
        UIPasteboard.general.string = text
        copiedItemID = id
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copiedItemID == id { copiedItemID = nil }
        }
    }

    private func regenerate(_ exchange: AnalysisExchange) {
        guard regeneratingExchangeID == nil else { return }
        regeneratingExchangeID = exchange.id
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            await store.regenerateAnalysis(exchangeID: exchange.id)
            regeneratingExchangeID = nil
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("conversation-bottom", anchor: .bottom)
            }
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }

        var loadedData: [Data] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            loadedData.append(data)
        }
        await importImageData(loadedData)
    }

    private func loadFiles(_ result: Result<[URL], Error>) {
        guard case let .success(urls) = result else {
            importError = "没有读取到可用图片，请重新选择。"
            return
        }

        Task {
            var loadedData: [Data] = []
            for url in urls.prefix(3) {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                if let data = try? Data(contentsOf: url) {
                    loadedData.append(data)
                }
            }
            await importImageData(loadedData)
        }
    }

    private func importImageData(_ loadedData: [Data]) async {
        guard !loadedData.isEmpty else {
            importError = "没有读取到可用图片，请重新选择。"
            return
        }

        isRecognizing = true
        importError = nil
        var recognizedText: [String] = []

        for data in loadedData.prefix(3) {
            let text = await OCRService.recognize(data: data)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { recognizedText.append(text) }
        }

        store.draft.imageData = Array(loadedData.prefix(3))
        if recognizedText.isEmpty {
            importError = "没有识别到清晰文字，请换一张图片或手动输入。"
        } else {
            let imported = recognizedText.joined(separator: "\n\n")
            if store.draft.conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.draft.conversationText = imported
            } else if !store.draft.conversationText.contains(imported) {
                store.draft.conversationText += "\n\n" + imported
            }
            importError = nil
        }
        isRecognizing = false
        composerFocused = true
    }
}

private struct ExpandedComposerView: View {
    @Binding var text: String
    @Binding var selection: NSRange
    @State private var isEditorFocused = false
    let placeholder: String
    let quickTopic: QuickTopic?
    let canSubmit: Bool
    let isAnalyzing: Bool
    let onDeleteToken: (() -> Void)?
    let onMetricsChange: (ComposerTextMetrics) -> Void
    let onCollapse: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AppTheme.pageBackground
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer(minLength: 0)

                    Button(action: onCollapse) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppTheme.primaryText)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("收起输入框")
                }
                .frame(height: 52)
                .padding(.horizontal, 8)

                if let quickTopic {
                    Button {
                        onDeleteToken?()
                    } label: {
                        Text(quickTopic.rawValue)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(AppTheme.accent, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .foregroundStyle(AppTheme.pureWhite)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    .padding(.bottom, 12)
                    .accessibilityLabel("移除快捷主题：\(quickTopic.rawValue)")
                }

                ComposerTextInput(
                    text: $text,
                    isFocused: $isEditorFocused,
                    selection: $selection,
                    placeholder: placeholder,
                    layout: .expanded,
                    onSubmit: onSubmit,
                    onDeleteToken: onDeleteToken,
                    onMetricsChange: onMetricsChange
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 76)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            Button(action: onSubmit) {
                Image(systemName: isAnalyzing ? "stop.fill" : "arrow.up")
                    .font(.body.weight(.bold))
                    .foregroundStyle(canSubmit || isAnalyzing ? AppTheme.pureWhite : AppTheme.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(canSubmit || isAnalyzing ? AppTheme.accent : AppTheme.subtleFill, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit && !isAnalyzing)
            .padding(.trailing, 16)
            .padding(.bottom, 14)
            .accessibilityLabel(isAnalyzing ? "停止分析" : "开始分析")
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isEditorFocused = true
            }
        }
        .accessibilityElement(children: .contain)
    }

}

private struct ThinkingIndicatorView: View {
    var body: some View {
        PhaseAnimator([false, true]) { expanded in
            Circle()
                .fill(AppTheme.accent)
                .frame(width: 18, height: 18)
                .scaleEffect(expanded ? 1 : 0.78)
                .opacity(expanded ? 1 : 0.64)
        } animation: { _ in
            .easeInOut(duration: 0.62)
        }
        .frame(width: 22, height: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("灵嗅正在思考")
    }
}

private struct ConversationExchangeView: View {
    let exchange: AnalysisExchange
    let roleCard: ChatRoleCard?
    @Binding var copiedItemID: UUID?
    let isRegenerating: Bool
    let onCopy: (UUID, String) -> Void
    let onOptimize: (String) -> Void
    let onRegenerate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            UserMessageView(draft: exchange.draft, roleCard: roleCard)

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                    Text("灵嗅分析")
                        .font(.headline)
                }

                Text(exchange.result.summary)
                    .font(.body)
                    .lineSpacing(4)
                    .textSelection(.enabled)

                AnalysisDetailSection(
                    title: "可能的含义",
                    systemImage: "quote.bubble",
                    items: exchange.result.possibleMeanings
                )

                AnalysisDetailSection(
                    title: "建议怎么沟通",
                    systemImage: "lightbulb",
                    items: exchange.result.suggestions
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("可以这样回复")
                        .font(.headline)

                    ForEach(exchange.replies) { reply in
                        ReplyOptionView(
                            reply: reply,
                            copied: copiedItemID == reply.id,
                            onCopy: { onCopy(reply.id, reply.text) },
                            onOptimize: { onOptimize(reply.text) }
                        )
                    }
                }

                AssistantActionRow(
                    copied: copiedItemID == exchange.id,
                    isRegenerating: isRegenerating,
                    shareText: shareText,
                    onCopy: { onCopy(exchange.id, shareText) },
                    onRegenerate: onRegenerate
                )
            }
            .padding(.horizontal, 4)
        }
    }

    private var shareText: String {
        let replies = exchange.replies.map { "\($0.label)：\($0.text)" }.joined(separator: "\n\n")
        return "灵嗅分析\n\n\(exchange.result.summary)\n\n可以这样回复\n\(replies)"
    }
}

private struct UserMessageView: View {
    let draft: AnalysisDraft
    let roleCard: ChatRoleCard?

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let roleCard {
                Label("分析对象：\(roleCard.name) · \(roleCard.relationship)", systemImage: "person.fill")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            if !draft.imageData.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(draft.imageData.prefix(3).enumerated()), id: \.offset) { _, data in
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 58, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .clipped()
                        }
                    }
                }
            }

            if let quote = draft.optimizationQuote {
                Label("优化引用：\(quote)", systemImage: "quote.opening")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            if let quickTopic = draft.quickTopic {
                Text(quickTopic.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accent.opacity(0.12), in: Capsule())
                    .accessibilityLabel("沟通主题：\(quickTopic.rawValue)")
            }

            Text(draft.conversationText)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppTheme.messageFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(maxWidth: 330, alignment: .trailing)

        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct AnalysisDetailSection: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(width: 20, height: 20)
                        .background(AppTheme.subtleFill, in: Circle())
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primaryText)
                        .lineSpacing(2)
                }
            }
        }
    }
}

private struct ReplyOptionView: View {
    let reply: ReplyOption
    let copied: Bool
    let onCopy: () -> Void
    let onOptimize: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    replyLabel
                    Spacer(minLength: 8)
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 0) {
                    replyLabel
                    HStack {
                        Spacer(minLength: 0)
                        actionButtons
                    }
                }
            }

            Text(reply.text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)

            Text(reply.rationale)
                .font(.caption)
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var replyLabel: some View {
        Text(reply.label)
            .font(.headline)
            .foregroundStyle(.tint)
    }

    private var actionButtons: some View {
        HStack(spacing: 2) {
            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .replyActionIcon()
            }
            .accessibilityLabel(copied ? "已复制" : "复制")

            Button(action: onOptimize) {
                Image(systemName: "wand.and.sparkles")
                    .replyActionIcon()
            }
            .accessibilityLabel("优化")
        }
        .font(.body)
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.secondaryText)
    }
}

private struct AssistantActionRow: View {
    let copied: Bool
    let isRegenerating: Bool
    let shareText: String
    let onCopy: () -> Void
    let onRegenerate: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onCopy) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(copied ? "已复制分析" : "复制分析")

            Button(action: onRegenerate) {
                Group {
                    if isRegenerating {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
            }
            .disabled(isRegenerating)
            .accessibilityLabel(isRegenerating ? "正在重新生成" : "重新生成")

            ShareLink(item: shareText) {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("分享分析")

            Spacer()
        }
        .buttonStyle(.plain)
        .foregroundStyle(AppTheme.secondaryText)
    }
}

private struct SelectedImageStrip: View {
    let imageData: [Data]
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(imageData.enumerated()), id: \.offset) { _, data in
                    if let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .clipped()
                    }
                }

                Button(action: onClear) {
                    Image(systemName: "xmark")
                        .frame(width: 44, height: 44)
                        .background(AppTheme.subtleFill, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("移除全部图片")
            }
        }
    }
}

private struct AttachmentOptionsView: View {
    let hasSelectedImages: Bool
    let onCamera: () -> Void
    let onPhotos: () -> Void
    let onFiles: () -> Void
    let onRemoveImages: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            attachmentRow(title: "相机", systemImage: "camera.fill", action: onCamera)
            attachmentRow(title: "照片", systemImage: "photo", action: onPhotos)
            attachmentRow(title: "文件", systemImage: "paperclip", action: onFiles)

            if hasSelectedImages {
                Divider()
                    .padding(.vertical, 4)
                attachmentRow(
                    title: "移除已选图片",
                    systemImage: "trash",
                    role: .destructive,
                    action: onRemoveImages
                )
            }
        }
        .padding(10)
        .frame(width: 260)
    }

    private func attachmentRow(
        title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .frame(width: 38, height: 38)
                    .background(AppTheme.subtleFill, in: Circle())
                Text(title)
                    .font(.body)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 4)
            .frame(minHeight: 54)
        }
        .buttonStyle(.plain)
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.9) {
                parent.onCapture(data)
            }
            parent.onDismiss()
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
            picker.dismiss(animated: true)
        }
    }
}

struct RoleCardSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @Binding var roleSelection: UUID?
    @Binding var identitySelection: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section("沟通对象") {
                    Button {
                        selectRoleCard(nil)
                    } label: {
                        HStack(spacing: 12) {
                            Text("不使用角色卡")
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            NativeSelectionIndicator(isSelected: roleSelection == nil)
                        }
                        .roleSelectionRow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(roleSelection == nil ? "已选择" : "未选择")

                    ForEach(store.roleCards) { card in
                        Button {
                            selectRoleCard(card.id)
                        } label: {
                            HStack(spacing: 12) {
                                RoleAvatarView(card: card, size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text([card.relationship, card.identity].filter { !$0.isEmpty }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                NativeSelectionIndicator(isSelected: roleSelection == card.id)
                            }
                            .roleSelectionRow()
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(roleSelection == card.id ? "已选择" : "未选择")
                    }
                }

                Section {
                    Button {
                        selectIdentityCard(nil)
                    } label: {
                        HStack(spacing: 12) {
                            Text("不使用身份卡")
                                .foregroundStyle(AppTheme.primaryText)
                            Spacer()
                            NativeSelectionIndicator(isSelected: identitySelection == nil)
                        }
                        .roleSelectionRow()
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(identitySelection == nil ? "已选择" : "未选择")

                    ForEach(store.identityCards) { card in
                        Button {
                            selectIdentityCard(card.id)
                        } label: {
                            HStack(spacing: 12) {
                                IdentityAvatarView(card: card, size: 42)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .foregroundStyle(AppTheme.primaryText)
                                    Text(card.identity.isEmpty ? "我的身份" : card.identity)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.secondaryText)
                                }
                                Spacer()
                                NativeSelectionIndicator(isSelected: identitySelection == card.id)
                            }
                            .roleSelectionRow()
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(identitySelection == card.id ? "已选择" : "未选择")
                    }
                } header: {
                    Text("我的身份")
                }
            }
            .navigationTitle("管理角色卡")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RoleCardListView { card in
                            roleSelection = card.id
                            dismiss()
                        }
                    } label: {
                        Text("管理")
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("管理角色卡")
                }
            }
        }
    }

    private func selectRoleCard(_ id: UUID?) {
        roleSelection = id
        dismiss()
    }

    private func selectIdentityCard(_ id: UUID?) {
        identitySelection = id
        dismiss()
    }
}

private struct NativeSelectionIndicator: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.title3)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .opacity(isSelected ? 1 : 0)
            .accessibilityHidden(true)
    }
}

private extension View {
    func replyActionIcon() -> some View {
        self
            .font(.subheadline.weight(.medium))
            // The Figma reference uses plain SF Symbols without a circular
            // container. Keep a compact rectangular hit target so adjacent
            // copy/optimize actions stay visually grouped.
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
    }

    func roleSelectionRow() -> some View {
        self
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }
}
