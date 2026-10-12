import Foundation
import Observation

@MainActor
@Observable
final class AppStore {
    var selectedTab: AppTab = .analysis
    var analysisPath: [AnalysisRoute] = []
    var draft = AnalysisDraft()
    var result: AnalysisResult?
    var selectedGoal = "部分接受"
    var customGoal = ""
    var replySettings = ReplySettings()
    var replies: [ReplyOption] = []
    var remainingAnalyses: Int

    var people: [PersonProfile] {
        didSet { persistPeople() }
    }

    var records: [AnalysisRecord] {
        didSet { persistRecords() }
    }

    private let defaults: UserDefaults
    private let persistsChanges: Bool

    init(defaults: UserDefaults = .standard, persistsChanges: Bool = true) {
        self.defaults = defaults
        self.persistsChanges = persistsChanges

        let calendar = Calendar.current
        if persistsChanges,
           let savedDate = defaults.object(forKey: "analysisQuotaDate") as? Date,
           calendar.isDate(savedDate, inSameDayAs: .now) {
            remainingAnalyses = defaults.object(forKey: "remainingAnalyses") == nil ? 3 : defaults.integer(forKey: "remainingAnalyses")
        } else {
            remainingAnalyses = 3
            if persistsChanges {
                defaults.set(Date.now, forKey: "analysisQuotaDate")
                defaults.set(3, forKey: "remainingAnalyses")
            }
        }

        let initialPeople: [PersonProfile]
        if persistsChanges,
           let peopleData = defaults.data(forKey: "savedPeople"),
           let decodedPeople = try? JSONDecoder().decode([PersonProfile].self, from: peopleData) {
            initialPeople = decodedPeople
        } else {
            initialPeople = Self.samplePeople
        }
        people = initialPeople

        if persistsChanges,
           let recordData = defaults.data(forKey: "savedRecords"),
           let decodedRecords = try? JSONDecoder().decode([AnalysisRecord].self, from: recordData) {
            records = decodedRecords
        } else {
            records = Self.sampleRecords(people: initialPeople)
        }
    }

    var associatedPerson: PersonProfile? {
        guard let id = draft.associatedPersonID else { return nil }
        return people.first { $0.id == id }
    }

    func prepareNewAnalysis(mode: InputMode, scene: QuickScene? = nil, personID: UUID? = nil) {
        draft = AnalysisDraft(inputMode: mode)
        draft.associatedPersonID = personID

        if let scene {
            draft.inputMode = .template
            draft.relation = scene.suggestedRelation
            draft.otherRole = scene.suggestedRelation
            draft.conversationText = scene.starterText
        }

        if let person = people.first(where: { $0.id == personID }) {
            draft.relation = person.relation
            draft.otherRole = person.identity.isEmpty ? person.relation : person.identity
            draft.relationshipStage = person.relationshipStage
        }

        result = nil
        replies = []
        selectedGoal = "部分接受"
        customGoal = ""
        replySettings = ReplySettings()
    }

    func runAnalysis() async {
        guard remainingAnalyses > 0 else { return }
        try? await Task.sleep(for: .seconds(1.6))
        result = LocalAnalysisEngine.analyze(draft: draft, person: associatedPerson)
        remainingAnalyses -= 1
        if persistsChanges { defaults.set(remainingAnalyses, forKey: "remainingAnalyses") }
    }

    func generateReplies() {
        guard let result else { return }
        let goal = customGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedGoal : customGoal
        replies = LocalAnalysisEngine.generateReplies(goal: goal, settings: replySettings, result: result)
    }

    func updateReply(id: UUID, text: String) {
        guard let index = replies.firstIndex(where: { $0.id == id }) else { return }
        replies[index].text = text
    }

    func toggleFavoriteReply(id: UUID) {
        guard let index = replies.firstIndex(where: { $0.id == id }) else { return }
        replies[index].isFavorite.toggle()
    }

    func saveRecord(using reply: ReplyOption) {
        guard !defaults.bool(forKey: "incognitoAnalysis") else { return }
        guard let result else { return }
        let person = associatedPerson
        let goal = customGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selectedGoal : customGoal
        if let existingIndex = records.firstIndex(where: {
            $0.originalText == draft.conversationText &&
            $0.personID == person?.id &&
            abs($0.date.timeIntervalSinceNow) < 600
        }) {
            records[existingIndex].selectedReply = reply.text
            records[existingIndex].goal = goal
            records[existingIndex].isFavorite = reply.isFavorite
            return
        }
        let record = AnalysisRecord(
            personID: person?.id,
            personName: person?.name ?? draft.relation,
            originalText: draft.conversationText,
            scene: draft.occasions.first ?? "沟通分析",
            goal: goal,
            resultSummary: result.summary,
            selectedReply: reply.text,
            isFavorite: reply.isFavorite
        )
        records.insert(record, at: 0)
    }

    func saveAnalysisOnly() {
        guard !defaults.bool(forKey: "incognitoAnalysis") else { return }
        guard let result else { return }
        let person = associatedPerson
        guard !records.contains(where: {
            $0.originalText == draft.conversationText &&
            $0.personID == person?.id &&
            abs($0.date.timeIntervalSinceNow) < 600
        }) else { return }

        records.insert(
            AnalysisRecord(
                personID: person?.id,
                personName: person?.name ?? draft.relation,
                originalText: draft.conversationText,
                scene: draft.occasions.first ?? "沟通分析",
                goal: "尚未选择",
                resultSummary: result.summary,
                selectedReply: ""
            ),
            at: 0
        )
    }

    func startAnalysis(for person: PersonProfile) {
        prepareNewAnalysis(mode: .text, personID: person.id)
        analysisPath = [.newAnalysis(.text, nil)]
        selectedTab = .analysis
    }

    func addPerson(_ person: PersonProfile) {
        people.insert(person, at: 0)
    }

    func updateFeedback(recordID: UUID, feedback: String) {
        if defaults.object(forKey: "saveFeedback") != nil, !defaults.bool(forKey: "saveFeedback") { return }
        guard let index = records.firstIndex(where: { $0.id == recordID }) else { return }
        records[index].feedback = feedback
    }

    func clearAllUserData() {
        people = []
        records = []
        defaults.removeObject(forKey: "savedPeople")
        defaults.removeObject(forKey: "savedRecords")
    }

    private func persistPeople() {
        guard persistsChanges, let data = try? JSONEncoder().encode(people) else { return }
        defaults.set(data, forKey: "savedPeople")
    }

    private func persistRecords() {
        guard persistsChanges, let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: "savedRecords")
    }

    static let samplePeople: [PersonProfile] = [
        PersonProfile(
            name: "王总",
            relation: "直属领导",
            category: "职场",
            identity: "部门负责人",
            avatarSymbol: "person.crop.circle.badge.checkmark",
            relationshipStage: "稳定合作",
            knownDuration: "1 年 2 个月",
            traits: ["结果导向", "偏好简洁", "表达克制"],
            preferences: ["先给结论，再解释", "关注完成时间和结果", "重要分歧更适合私聊"],
            risks: ["只解释原因，不给解决方案", "长时间不反馈", "在群聊中直接反驳"],
            strategies: ["回复包含明确时间", "不确定时先确认优先级", "同步结果时附上关键变化"],
            notes: "不喜欢长篇解释，更关心什么时候完成。"
        ),
        PersonProfile(
            name: "客户 A",
            relation: "客户",
            category: "客户",
            identity: "采购负责人",
            avatarSymbol: "building.2.crop.circle.fill",
            relationshipStage: "正在建立信任",
            knownDuration: "3 个月",
            traits: ["决策谨慎", "重视价格", "回复较慢"],
            preferences: ["需要清晰的成本依据", "倾向书面确认"],
            risks: ["频繁催促", "没有条件地直接降价"],
            strategies: ["约定下一次跟进节点", "用范围或付款条件交换让步"],
            notes: "内部决策链较长。",
            lastInteraction: .now.addingTimeInterval(-86_400)
        ),
        PersonProfile(
            name: "妈妈",
            relation: "亲人",
            category: "家庭",
            identity: "母亲",
            avatarSymbol: "heart.circle.fill",
            relationshipStage: "关系稳定",
            knownDuration: "长期",
            traits: ["重视回应", "表达直接", "容易担心"],
            preferences: ["先表达理解", "提供具体安排会更安心"],
            risks: ["只讲道理", "突然中断话题"],
            strategies: ["确认关心背后的需求", "表达边界时保留关系温度"],
            lastInteraction: .now.addingTimeInterval(-172_800)
        )
    ]

    static func sampleRecords(people: [PersonProfile]) -> [AnalysisRecord] {
        [
            AnalysisRecord(
                personID: people.first?.id,
                personName: "王总",
                originalText: "这个方案再优化一下，你再多想想。",
                scene: "职场",
                goal: "部分接受",
                date: .now.addingTimeInterval(-3_600),
                resultSummary: "更可能在表达对结果的不满意，并期待明确行动。",
                selectedReply: "收到，我会先梳理方案结构和关键表达，今天下午整理一版再同步您确认。",
                isFavorite: true
            ),
            AnalysisRecord(
                personID: people.dropFirst().first?.id,
                personName: "客户 A",
                originalText: "价格能不能再降一点？我们内部还要商量。",
                scene: "商务",
                goal: "继续谈判",
                date: .now.addingTimeInterval(-86_400),
                resultSummary: "客户表现出兴趣，但正在测试价格空间。",
                selectedReply: "理解您的预算考虑，我们可以一起确认范围和交付优先级，再给您一个更匹配的方案。"
            )
        ]
    }
}
