import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var selectedTab: AppTab = .analysis
    var draft = AnalysisDraft()
    var result: AnalysisResult?
    var replies: [ReplyOption] = []
    var isAnalyzing = false

    var roleCards: [ChatRoleCard] {
        didSet { persistRoleCards() }
    }

    private let defaults: UserDefaults
    private let persistsChanges: Bool
    private static let roleCardsKey = "lingxiu.roleCards.v101"

    init(defaults: UserDefaults = .standard, persistsChanges: Bool = true) {
        self.defaults = defaults
        self.persistsChanges = persistsChanges

        if persistsChanges,
           let data = defaults.data(forKey: Self.roleCardsKey),
           let savedCards = try? JSONDecoder().decode([ChatRoleCard].self, from: data) {
            roleCards = savedCards
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
    }

    var selectedRoleCard: ChatRoleCard? {
        guard let id = draft.selectedRoleCardID else { return nil }
        return roleCards.first { $0.id == id }
    }

    @discardableResult
    func runAnalysis() async -> Bool {
        guard draft.hasUsableText else { return false }
        isAnalyzing = true
        result = nil
        replies = []

        try? await Task.sleep(for: .milliseconds(650))
        let analysis = LocalAnalysisEngine.analyze(draft: draft, roleCard: selectedRoleCard)
        result = analysis
        replies = LocalAnalysisEngine.generateReplies(result: analysis, roleCard: selectedRoleCard)
        isAnalyzing = false
        return true
    }

    func clearAnalysis(keepingInput: Bool = true) {
        result = nil
        replies = []
        if !keepingInput {
            draft = AnalysisDraft()
        }
    }

    func startAnalysis(using roleCard: ChatRoleCard) {
        draft = AnalysisDraft(selectedRoleCardID: roleCard.id)
        result = nil
        replies = []
        selectedTab = .analysis
    }

    func saveRoleCard(_ card: ChatRoleCard) {
        if let index = roleCards.firstIndex(where: { $0.id == card.id }) {
            roleCards[index] = card
        } else {
            roleCards.insert(card, at: 0)
        }
    }

    func deleteRoleCard(id: UUID) {
        roleCards.removeAll { $0.id == id }
        if draft.selectedRoleCardID == id {
            draft.selectedRoleCardID = nil
        }
    }

    private func persistRoleCards() {
        guard persistsChanges,
              let data = try? JSONEncoder().encode(roleCards) else { return }
        defaults.set(data, forKey: Self.roleCardsKey)
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
