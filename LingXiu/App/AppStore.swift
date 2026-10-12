import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var draft = AnalysisDraft()
    var result: AnalysisResult?
    var replies: [ReplyOption] = []
    var exchanges: [AnalysisExchange] = []
    var pendingDraft: AnalysisDraft?
    var isAnalyzing = false
    var pointErrorMessage: String?
    var analysisServiceNotice: String?
    var selectedExchangeID: UUID?
    private var analysisRequestID = UUID()
    private(set) var currentConversationID = UUID()
    private let aiService: ArkAIService?

    var roleCards: [ChatRoleCard] {
        didSet { persistRoleCards() }
    }

    var identityCards: [IdentityCard] {
        didSet { persistIdentityCards() }
    }

    var pointTransactions: [PointTransaction] {
        didSet { persistPointTransactions() }
    }

    var userProfile: UserProfile

    private let defaults: UserDefaults
    private let persistsChanges: Bool
    private static let roleCardsKey = "lingxiu.roleCards.v101"
    private static let identityCardsKey = "lingxiu.identityCards.v101"
    private static let pointTransactionsKey = "lingxiu.pointTransactions.v101"
    private static let userProfileKey = "lingxiu.userProfile.v101"

    init(
        defaults: UserDefaults = .standard,
        persistsChanges: Bool = true,
        aiService: ArkAIService? = nil
    ) {
        self.defaults = defaults
        self.persistsChanges = persistsChanges
        // Unit-test stores stay deterministic and never make a network call.
        // The app store reads the runtime Ark configuration on normal launch.
        self.aiService = aiService ?? (persistsChanges ? ArkAIService() : nil)

        if persistsChanges,
           let data = defaults.data(forKey: Self.userProfileKey),
           let savedProfile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            // Normalize profiles written by older builds so a long name can
            // never push the points and search controls out of the sidebar.
            userProfile = UserProfile(
                displayName: savedProfile.displayName,
                points: savedProfile.points,
                avatarData: savedProfile.avatarData
            )
        } else {
            userProfile = UserProfile()
        }

        if persistsChanges,
           let data = defaults.data(forKey: Self.identityCardsKey),
           let savedCards = try? JSONDecoder().decode([IdentityCard].self, from: data) {
            identityCards = savedCards.map(Self.normalizedIdentityCard)
        } else {
            identityCards = []
        }

        if persistsChanges,
           let data = defaults.data(forKey: Self.roleCardsKey),
           let savedCards = try? JSONDecoder().decode([ChatRoleCard].self, from: data) {
            roleCards = savedCards.map(Self.normalizedRoleCard)
        } else if persistsChanges,
                  let legacyData = defaults.data(forKey: "savedPeople"),
                  let legacyPeople = try? JSONDecoder().decode([LegacyPersonProfile].self, from: legacyData) {
            let migratedCards = legacyPeople.map(ChatRoleCard.init(legacy:))
            roleCards = migratedCards
            if let data = try? JSONEncoder().encode(migratedCards) {
                defaults.set(data, forKey: Self.roleCardsKey)
            }
        } else {
            roleCards = []
        }

        if persistsChanges,
           let data = defaults.data(forKey: Self.pointTransactionsKey),
           let savedTransactions = try? JSONDecoder().decode([PointTransaction].self, from: data) {
            // Repair the short-lived V1.01 prototype records that were
            // written before string interpolation was corrected in the
            // purchase flow. This keeps existing local history readable.
            pointTransactions = savedTransactions.map(Self.normalizedPointTransaction)
        } else {
            pointTransactions = []
        }

    }

    // AppStore never performs actor-isolated cleanup. Opting out of an
    // executor-hopped deinit also avoids a Swift 6 simulator runtime fault
    // when short-lived stores are released by XCTest.
    nonisolated deinit { }

    var selectedRoleCard: ChatRoleCard? {
        guard let id = draft.selectedRoleCardID else { return nil }
        return roleCards.first { $0.id == id }
    }

    var selectedIdentityCard: IdentityCard? {
        guard let id = draft.selectedIdentityCardID else { return nil }
        return identityCards.first { $0.id == id }
    }

    /// The conversation currently visible in the main chat. The sidebar uses
    /// `exchanges` directly so older conversations remain available after a
    /// new analysis starts.
    var currentExchanges: [AnalysisExchange] {
        exchanges.filter { $0.conversationID == currentConversationID }
    }

    var isRemoteAIConfigured: Bool {
        aiService?.isConfigured == true
    }

    var remoteAIUsesServerProxy: Bool {
        aiService?.usesServerProxy == true
    }

    @discardableResult
    func runAnalysis() async -> Bool {
        guard draft.hasUsableText else { return false }
        guard userProfile.points > 0 else {
            pointErrorMessage = "当前积分已用完，请先购买积分后再进行沟通分析。"
            return false
        }

        let submittedDraft = draft
        let roleCard = roleCard(for: submittedDraft)
        let identityCard = identityCard(for: submittedDraft)
        let requestID = UUID()
        analysisRequestID = requestID
        pendingDraft = submittedDraft
        isAnalyzing = true
        selectedExchangeID = nil
        result = nil
        replies = []
        draft = AnalysisDraft(
            selectedRoleCardID: submittedDraft.selectedRoleCardID,
            selectedIdentityCardID: submittedDraft.selectedIdentityCardID
        )

        // Keep the local demo's thinking state visible long enough to read and
        // stop. Unit-test stores skip the presentation delay.
        try? await Task.sleep(for: persistsChanges ? .milliseconds(1_500) : .milliseconds(10))
        guard requestID == analysisRequestID else { return false }
        let localAnalysis = LocalAnalysisEngine.analyze(
            draft: submittedDraft,
            roleCard: roleCard,
            identityCard: identityCard
        )
        let localReplies = LocalAnalysisEngine.generateReplies(
            result: localAnalysis,
            roleCard: roleCard,
            identityCard: identityCard
        )
        var analysis = localAnalysis
        var generatedReplies = localReplies

        // The on-device engine remains a safe fallback for development,
        // offline use and API errors. When a key is configured, the same
        // product flow transparently uses Ark's Responses API.
        analysisServiceNotice = nil
        if let aiService, aiService.isConfigured {
            do {
                let remote = try await aiService.analyze(
                    draft: submittedDraft,
                    roleCard: roleCard,
                    identityCard: identityCard,
                    fallbackKind: localAnalysis.kind
                )
                analysis = remote.result
                generatedReplies = remote.replies
            } catch {
                let reason = (error as? LocalizedError)?.errorDescription
                analysisServiceNotice = [
                    "云端 AI 暂时不可用，本次已使用设备本地分析。",
                    reason
                ]
                .compactMap { $0 }
                .joined(separator: "\n")
            }
        }
        guard requestID == analysisRequestID else { return false }

        let usageDetail: String
        if !submittedDraft.imageData.isEmpty {
            usageDetail = submittedDraft.hasUsableText ? "文字与图片分析" : "图片分析"
        } else if let quickTopic = submittedDraft.quickTopic {
            usageDetail = quickTopic.rawValue
        } else {
            usageDetail = "文字分析"
        }
        guard consumePoints(1, title: "沟通分析", detail: usageDetail) else {
            // This can only happen if another flow consumed the final point
            // while this request was running. Restore the submitted draft so
            // the user never loses their input.
            draft = submittedDraft
            pendingDraft = nil
            isAnalyzing = false
            pointErrorMessage = "当前积分已用完，请先购买积分后再进行沟通分析。"
            return false
        }
        pointErrorMessage = nil
        result = analysis
        replies = generatedReplies
        let exchange = AnalysisExchange(
            conversationID: currentConversationID,
            draft: submittedDraft,
            result: analysis,
            replies: generatedReplies
        )
        exchanges.append(exchange)
        selectedExchangeID = exchange.id
        pendingDraft = nil
        isAnalyzing = false
        return true
    }

    func cancelAnalysis() {
        analysisRequestID = UUID()
        if let pendingDraft {
            draft = pendingDraft
        }
        pendingDraft = nil
        isAnalyzing = false
    }

    func clearAnalysis(keepingInput: Bool = true) {
        result = nil
        replies = []
        pendingDraft = nil
        if !keepingInput {
            draft = AnalysisDraft(
                selectedRoleCardID: draft.selectedRoleCardID,
                selectedIdentityCardID: draft.selectedIdentityCardID
            )
        }
    }

    func clearConversation(keepingRoleCard: Bool = true) {
        analysisRequestID = UUID()
        let selectedRoleCardID = keepingRoleCard ? draft.selectedRoleCardID : nil
        let selectedIdentityCardID = keepingRoleCard ? draft.selectedIdentityCardID : nil

        // Clearing is a view-level action: the composer becomes a fresh chat,
        // while the sidebar keeps a useful recent entry when this was the
        // user's only conversation. Once older chats already exist, remove
        // the cleared conversation and leave those older entries untouched.
        let currentConversationHasHistory = exchanges.contains {
            $0.conversationID == currentConversationID
        }
        let hasOtherRecentChats = exchanges.contains {
            $0.conversationID != currentConversationID
        }
        if currentConversationHasHistory && hasOtherRecentChats {
            exchanges.removeAll { $0.conversationID == currentConversationID }
        }

        currentConversationID = UUID()
        draft = AnalysisDraft(
            selectedRoleCardID: selectedRoleCardID,
            selectedIdentityCardID: selectedIdentityCardID
        )
        result = nil
        replies = []
        pendingDraft = nil
        isAnalyzing = false
        selectedExchangeID = nil
    }

    /// Starts a fresh composer without deleting the user's recent chats.
    /// Recent exchanges are the chat history shown in the sidebar; a new
    /// analysis should simply detach the current draft from that history and
    /// let the next completed analysis be inserted at the top.
    func beginNewConversation() {
        analysisRequestID = UUID()
        currentConversationID = UUID()
        let selectedRoleCardID = draft.selectedRoleCardID
        let selectedIdentityCardID = draft.selectedIdentityCardID
        draft = AnalysisDraft(
            selectedRoleCardID: selectedRoleCardID,
            selectedIdentityCardID: selectedIdentityCardID
        )
        result = nil
        replies = []
        pendingDraft = nil
        isAnalyzing = false
        selectedExchangeID = nil
    }

    func restoreDraft(from exchange: AnalysisExchange) {
        currentConversationID = exchange.conversationID
        draft = exchange.draft
        selectedExchangeID = exchange.id
    }

    func selectQuickTopic(_ topic: QuickTopic?) {
        guard draft.quickTopic != topic else { return }
        draft.quickTopic = topic
        if topic != nil {
            draft.optimizationQuote = nil
        }
        selectedExchangeID = nil
    }

    func beginOptimization(for reply: String) {
        draft.optimizationQuote = reply
        draft.conversationText = ""
        draft.quickTopic = nil
        selectedExchangeID = nil
    }

    func regenerateAnalysis(exchangeID: UUID) async {
        guard let index = exchanges.firstIndex(where: { $0.id == exchangeID }) else { return }
        let sourceDraft = exchanges[index].draft
        let roleCard = roleCard(for: sourceDraft)
        let identityCard = identityCard(for: sourceDraft)

        try? await Task.sleep(for: persistsChanges ? .milliseconds(900) : .milliseconds(10))

        let analysis = LocalAnalysisEngine.analyze(
            draft: sourceDraft,
            roleCard: roleCard,
            identityCard: identityCard
        )
        let generatedReplies = LocalAnalysisEngine.generateReplies(
            result: analysis,
            roleCard: roleCard,
            identityCard: identityCard
        )

        guard let currentIndex = exchanges.firstIndex(where: { $0.id == exchangeID }) else { return }
        exchanges[currentIndex].result = analysis
        exchanges[currentIndex].replies = generatedReplies
        exchanges[currentIndex].createdAt = .now
        selectedExchangeID = exchangeID

        if exchanges.last?.id == exchangeID {
            result = analysis
            replies = generatedReplies
        }
    }

    func selectRoleCard(id: UUID?) {
        guard draft.selectedRoleCardID != id else { return }
        draft.selectedRoleCardID = id
        draft.quickTopic = nil
        selectedExchangeID = nil
    }

    func selectIdentityCard(id: UUID?) {
        guard draft.selectedIdentityCardID != id else { return }
        draft.selectedIdentityCardID = id
        draft.quickTopic = nil
        selectedExchangeID = nil
    }

    func rewriteReply(exchangeID: UUID, replyID: UUID, tone: ReplyTone) {
        guard let exchangeIndex = exchanges.firstIndex(where: { $0.id == exchangeID }),
              let replyIndex = exchanges[exchangeIndex].replies.firstIndex(where: { $0.id == replyID }) else {
            return
        }

        var reply = exchanges[exchangeIndex].replies[replyIndex]
        reply.text = LocalAnalysisEngine.rewrite(reply.text, tone: tone)
        reply.rationale = "已按“\(tone.title)”优化，你仍可以继续复制或继续优化。"
        exchanges[exchangeIndex].replies[replyIndex] = reply
        if exchanges[exchangeIndex].id == exchanges.last?.id {
            replies = exchanges[exchangeIndex].replies
        }
    }

    func startAnalysis(using roleCard: ChatRoleCard) {
        draft = AnalysisDraft(
            selectedRoleCardID: roleCard.id,
            selectedIdentityCardID: draft.selectedIdentityCardID
        )
        result = nil
        replies = []
        pendingDraft = nil
        selectedExchangeID = nil
    }

    func saveRoleCard(_ card: ChatRoleCard) {
        let card = Self.normalizedRoleCard(card)
        if let index = roleCards.firstIndex(where: { $0.id == card.id }) {
            roleCards[index] = card
        } else {
            roleCards.insert(card, at: 0)
        }
    }

    func deleteRoleCard(id: UUID) {
        roleCards.removeAll { $0.id == id }
        if draft.selectedRoleCardID == id {
            selectRoleCard(id: nil)
        }
    }

    func saveIdentityCard(_ card: IdentityCard) {
        let card = Self.normalizedIdentityCard(card)
        if let index = identityCards.firstIndex(where: { $0.id == card.id }) {
            identityCards[index] = card
        } else {
            identityCards.insert(card, at: 0)
        }
    }

    func deleteIdentityCard(id: UUID) {
        identityCards.removeAll { $0.id == id }
        if draft.selectedIdentityCardID == id {
            selectIdentityCard(id: nil)
        }
    }

    func updateUserProfile(displayName: String, avatarData: Data?) {
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { return }
        userProfile = UserProfile(
            displayName: String(normalizedName.prefix(UserProfile.maximumDisplayNameLength)),
            points: userProfile.points,
            avatarData: avatarData
        )
        persistUserProfile()
    }

    @discardableResult
    func consumePoints(
        _ amount: Int,
        title: String = "沟通分析",
        detail: String = "一次沟通分析"
    ) -> Bool {
        guard amount > 0, userProfile.points >= amount else { return false }
        userProfile = UserProfile(
            displayName: userProfile.displayName,
            points: userProfile.points - amount,
            avatarData: userProfile.avatarData
        )
        persistUserProfile()
        pointErrorMessage = nil
        pointTransactions.insert(
            PointTransaction(amount: -amount, title: title, detail: detail),
            at: 0
        )
        return true
    }

    func addPoints(
        _ amount: Int,
        title: String = "购买积分",
        detail: String = ""
    ) {
        guard amount > 0 else { return }
        userProfile = UserProfile(
            displayName: userProfile.displayName,
            points: userProfile.points + amount,
            avatarData: userProfile.avatarData
        )
        persistUserProfile()
        pointErrorMessage = nil
        pointTransactions.insert(
            PointTransaction(amount: amount, title: title, detail: detail),
            at: 0
        )
    }

    private func persistRoleCards() {
        guard persistsChanges,
              let data = try? JSONEncoder().encode(roleCards) else { return }
        defaults.set(data, forKey: Self.roleCardsKey)
    }

    private func persistIdentityCards() {
        guard persistsChanges,
              let data = try? JSONEncoder().encode(identityCards) else { return }
        defaults.set(data, forKey: Self.identityCardsKey)
    }

    private func persistUserProfile() {
        guard persistsChanges,
              let data = try? JSONEncoder().encode(userProfile) else { return }
        defaults.set(data, forKey: Self.userProfileKey)
    }

    private func persistPointTransactions() {
        guard persistsChanges,
              let data = try? JSONEncoder().encode(pointTransactions) else { return }
        defaults.set(data, forKey: Self.pointTransactionsKey)
    }

    private func roleCard(for draft: AnalysisDraft) -> ChatRoleCard? {
        guard let id = draft.selectedRoleCardID else { return nil }
        return roleCards.first { $0.id == id }
    }

    private func identityCard(for draft: AnalysisDraft) -> IdentityCard? {
        guard let id = draft.selectedIdentityCardID else { return nil }
        return identityCards.first { $0.id == id }
    }

    private static func normalizedRoleCard(_ card: ChatRoleCard) -> ChatRoleCard {
        var normalized = card
        normalized.name = String(card.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(ChatRoleCard.maximumNameLength))
        return normalized
    }

    private static func normalizedIdentityCard(_ card: IdentityCard) -> IdentityCard {
        var normalized = card
        normalized.name = String(card.name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(IdentityCard.maximumNameLength))
        return normalized
    }

    private static func normalizedPointTransaction(_ transaction: PointTransaction) -> PointTransaction {
        guard transaction.detail.contains("(package.points)") else { return transaction }
        return PointTransaction(
            id: transaction.id,
            amount: transaction.amount,
            title: transaction.title,
            detail: "\(abs(transaction.amount)) 积分包",
            createdAt: transaction.createdAt
        )
    }
}

private struct LegacyPersonProfile: Codable {
    let id: UUID
    var name: String
    var relation: String
    var category: String
    var identity: String
    var avatarSymbol: String
    var relationshipStage: String
    var knownDuration: String
    var traits: [String]
    var preferences: [String]
    var risks: [String]
    var strategies: [String]
    var notes: String
    var lastInteraction: Date
}

private extension ChatRoleCard {
    init(legacy person: LegacyPersonProfile) {
        let descriptionParts = [
            person.notes,
            person.traits.isEmpty ? "" : "特点：\(person.traits.joined(separator: "、"))",
            person.relationshipStage.isEmpty ? "" : "关系阶段：\(person.relationshipStage)",
            person.knownDuration.isEmpty ? "" : "认识时长：\(person.knownDuration)"
        ].filter { !$0.isEmpty }

        self.init(
            id: person.id,
            name: person.name,
            relationship: person.relation,
            identity: person.identity,
            userDescription: descriptionParts.joined(separator: "；"),
            speakingStyle: person.preferences.joined(separator: "、"),
            notes: person.strategies.joined(separator: "、"),
            updatedAt: person.lastInteraction
        )
    }
}
