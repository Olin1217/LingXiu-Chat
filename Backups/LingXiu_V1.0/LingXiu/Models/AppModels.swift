import Foundation

enum AppTab: Hashable {
    case analysis
    case people
    case records
    case profile
}

enum InputMode: String, CaseIterable, Identifiable, Codable, Hashable {
    case screenshot = "截图"
    case text = "文字"
    case template = "模板"

    var id: Self { self }
}

enum QuickScene: String, CaseIterable, Identifiable, Codable, Hashable {
    case replyToLeader = "回复领导"
    case declineRequest = "拒绝请求"
    case clientCommunication = "客户沟通"
    case colleagueWork = "同事协作"
    case family = "家庭关系"
    case relationship = "恋爱沟通"
    case followUp = "催进度"
    case apology = "道歉解释"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .replyToLeader: "briefcase.fill"
        case .declineRequest: "hand.raised.fill"
        case .clientCommunication: "person.2.fill"
        case .colleagueWork: "person.3.fill"
        case .family: "house.fill"
        case .relationship: "heart.fill"
        case .followUp: "clock.badge.exclamationmark.fill"
        case .apology: "bubble.left.and.exclamationmark.bubble.right.fill"
        }
    }

    var suggestedRelation: String {
        switch self {
        case .replyToLeader: "直属领导"
        case .declineRequest: "同事"
        case .clientCommunication, .followUp: "客户"
        case .colleagueWork: "同事"
        case .family: "亲人"
        case .relationship, .apology: "恋人"
        }
    }

    var starterText: String {
        switch self {
        case .replyToLeader: "领导：这个方案感觉还需要再打磨一下。\n我：好的。\n领导：你再多想想。"
        case .declineRequest: "同事：这部分你今天能不能也帮我一起做了？我手上有点忙。"
        case .clientCommunication: "客户：方案还可以，价格能不能再降一点？我们还要内部商量。"
        case .colleagueWork: "同事：这个不是我负责的，你找其他人确认一下吧。"
        case .family: "家人：我们都是为你好，你怎么就不听劝呢？"
        case .relationship: "对方：没事，你忙你的吧。"
        case .followUp: "我：上周的确认结果方便同步一下吗？\n对方：后面再说。"
        case .apology: "对方：我觉得你刚才那样说让我很不舒服。"
        }
    }
}

enum AnalysisRoute: Hashable {
    case newAnalysis(InputMode, QuickScene?)
    case supplement
    case analyzing
    case result
    case goals
    case replyStyle
    case replies
    case editReply(UUID)
}

struct AnalysisDraft: Hashable {
    var inputMode: InputMode = .screenshot
    var screenshotData: [Data] = []
    var conversationText = ""
    var relation = "直属领导"
    var occasions: Set<String> = ["私聊"]
    var background = ""
    var worries: Set<String> = []
    var desiredOutputs: Set<String> = ["分析对方意图", "生成回复"]
    var userRole = "员工"
    var otherRole = "直属领导"
    var powerRelation = "对方明显更强势"
    var relationshipStage = "日常合作"
    var responseTiming = "今天"
    var sceneDetails: Set<String> = ["工作日", "私密沟通"]
    var associatedPersonID: UUID?
    var privacyMode = "自动隐藏"

    var hasUsableInput: Bool {
        !conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !screenshotData.isEmpty
    }
}

struct PersonProfile: Identifiable, Codable, Hashable {
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

    init(
        id: UUID = UUID(),
        name: String,
        relation: String,
        category: String = "职场",
        identity: String = "",
        avatarSymbol: String = "person.crop.circle.fill",
        relationshipStage: String = "日常合作",
        knownDuration: String = "",
        traits: [String] = [],
        preferences: [String] = [],
        risks: [String] = [],
        strategies: [String] = [],
        notes: String = "",
        lastInteraction: Date = .now
    ) {
        self.id = id
        self.name = name
        self.relation = relation
        self.category = category
        self.identity = identity
        self.avatarSymbol = avatarSymbol
        self.relationshipStage = relationshipStage
        self.knownDuration = knownDuration
        self.traits = traits
        self.preferences = preferences
        self.risks = risks
        self.strategies = strategies
        self.notes = notes
        self.lastInteraction = lastInteraction
    }
}

enum Likelihood: String, Codable, Hashable {
    case high = "高可能"
    case medium = "中等可能"
    case low = "低可能"
    case insufficient = "信息不足"
}

struct Intention: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var likelihood: Likelihood
    var evidence: [String]

    init(id: UUID = UUID(), label: String, likelihood: Likelihood, evidence: [String]) {
        self.id = id
        self.label = label
        self.likelihood = likelihood
        self.evidence = evidence
    }
}

struct CommunicationSignal: Identifiable, Codable, Hashable {
    let id: UUID
    var dimension: String
    var symbol: String
    var finding: String
    var evidence: String

    init(id: UUID = UUID(), dimension: String, symbol: String, finding: String, evidence: String) {
        self.id = id
        self.dimension = dimension
        self.symbol = symbol
        self.finding = finding
        self.evidence = evidence
    }
}

struct RelationshipState: Codable, Hashable {
    var trust = "建立中"
    var pressure = "中"
    var power = "对方更强"
    var stage = "稳定合作"
    var advice = "先确认对方关注点，再给出清晰的下一步。"
}

struct RiskNotice: Identifiable, Codable, Hashable {
    let id: UUID
    var level: String
    var message: String

    init(id: UUID = UUID(), level: String, message: String) {
        self.id = id
        self.level = level
        self.message = message
    }
}

struct AnalysisResult: Codable, Hashable {
    var summary: String
    var surfaceMeaning: String
    var intentions: [Intention]
    var otherPossibilities: [String]
    var signals: [CommunicationSignal]
    var traits: [String]
    var expectations: [Intention]
    var relationship: RelationshipState
    var risks: [RiskNotice]
    var recommendedActions: [String]
}

enum ReplyTone: String, CaseIterable, Identifiable, Codable, Hashable {
    case professional = "专业稳妥"
    case concise = "简洁直接"
    case warm = "温和礼貌"
    case tactful = "高情商"
    case firm = "坚定有边界"
    case natural = "轻松自然"
    case formal = "正式"

    var id: Self { self }
}

enum ReplyLength: String, CaseIterable, Identifiable, Codable, Hashable {
    case oneSentence = "一句话"
    case short = "简短"
    case standard = "标准"
    case detailed = "详细"

    var id: Self { self }
}

struct ReplySettings: Hashable, Codable {
    var tone: ReplyTone = .professional
    var length: ReplyLength = .standard
    var warmth = 0.5
    var firmness = 0.5
    var inclusions: Set<String> = ["下一步动作", "完成时间"]
    var exclusions: Set<String> = []
}

struct ReplyOption: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var text: String
    var isFavorite: Bool

    init(id: UUID = UUID(), label: String, text: String, isFavorite: Bool = false) {
        self.id = id
        self.label = label
        self.text = text
        self.isFavorite = isFavorite
    }
}

struct AnalysisRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var personID: UUID?
    var personName: String
    var originalText: String
    var scene: String
    var goal: String
    var date: Date
    var resultSummary: String
    var selectedReply: String
    var isFavorite: Bool
    var feedback: String?

    init(
        id: UUID = UUID(),
        personID: UUID? = nil,
        personName: String,
        originalText: String,
        scene: String,
        goal: String,
        date: Date = .now,
        resultSummary: String,
        selectedReply: String,
        isFavorite: Bool = false,
        feedback: String? = nil
    ) {
        self.id = id
        self.personID = personID
        self.personName = personName
        self.originalText = originalText
        self.scene = scene
        self.goal = goal
        self.date = date
        self.resultSummary = resultSummary
        self.selectedReply = selectedReply
        self.isFavorite = isFavorite
        self.feedback = feedback
    }
}
