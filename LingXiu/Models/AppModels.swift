import Foundation

struct UserProfile: Codable, Hashable {
    static let maximumDisplayNameLength = 16

    var displayName: String
    var points: Int
    var avatarData: Data?

    init(
        displayName: String = "灵嗅用户",
        points: Int = 200,
        avatarData: Data? = nil
    ) {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = String((normalized.isEmpty ? "灵嗅用户" : normalized).prefix(Self.maximumDisplayNameLength))
        self.points = max(points, 0)
        self.avatarData = avatarData
    }

}

/// A single balance change. Positive amounts are credits (for example a
/// purchase); negative amounts are usage (for example a completed analysis).
/// Keeping the signed amount makes the history view and future export paths
/// share one source of truth.
struct PointTransaction: Identifiable, Codable, Hashable {
    let id: UUID
    let amount: Int
    let title: String
    let detail: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        amount: Int,
        title: String,
        detail: String = "",
        createdAt: Date = .now
    ) {
        self.id = id
        self.amount = amount
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }

    var isCredit: Bool { amount > 0 }
}

struct AnalysisDraft: Hashable {
    var conversationText = ""
    var imageData: [Data] = []
    var selectedRoleCardID: UUID?
    var selectedIdentityCardID: UUID?
    var optimizationQuote: String?
    var quickTopic: QuickTopic?

    var hasUsableText: Bool {
        !conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var effectiveConversationText: String {
        let message: String
        if let optimizationQuote,
           !optimizationQuote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = "待优化的回复：\(optimizationQuote)\n优化方向：\(conversationText)"
        } else {
            message = conversationText
        }

        guard let quickTopic else { return message }
        return "沟通主题：\(quickTopic.rawValue)\n\(message)"
    }
}

enum QuickTopic: String, CaseIterable, Identifiable, Hashable {
    case dealingWithLeader = "应对领导"
    case communicationMentor = "沟通导师"
    case colleagueRelations = "同事相处"
    case politeRefusal = "礼貌拒绝"
    case expressDissatisfaction = "表达不满"
    case urgeProgress = "催促进度"
    case apologyAndExplanation = "道歉解释"
    case makeARequest = "提出请求"
    case seekOpportunity = "争取机会"
    case salaryNegotiation = "谈薪加薪"
    case romanticCommunication = "恋爱沟通"
    case ambiguityJudgment = "暧昧判断"
    case easeConflict = "缓和矛盾"
    case friendRelations = "朋友相处"
    case familyCommunication = "家庭沟通"
    case setBoundaries = "设立边界"
    case judgeAttitude = "判断态度"
    case identifyProbing = "识别试探"

    var id: Self { self }
}

struct IdentityCard: Identifiable, Codable, Hashable {
    static let maximumNameLength = 16

    let id: UUID
    var name: String
    var identity: String
    var userDescription: String
    var zodiacSign: String
    var birthday: String
    var birthDetails: String
    var mbti: String
    var speakingStyle: String
    var notes: String
    var avatarData: Data?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        identity: String = "",
        userDescription: String = "",
        zodiacSign: String = "未填写",
        birthday: String = "",
        birthDetails: String = "",
        mbti: String = "未填写",
        speakingStyle: String = "",
        notes: String = "",
        avatarData: Data? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumNameLength))
        self.identity = identity
        self.userDescription = userDescription
        self.zodiacSign = zodiacSign
        self.birthday = birthday
        self.birthDetails = birthDetails
        self.mbti = mbti
        self.speakingStyle = speakingStyle
        self.notes = notes
        self.avatarData = avatarData
        self.updatedAt = updatedAt
    }

    var contextSummary: String {
        var details = ["我的身份名称：\(name)"]
        if !identity.isEmpty { details.append("身份：\(identity)") }
        if !userDescription.isEmpty { details.append("自我描述：\(userDescription)") }
        if zodiacSign != "未填写" { details.append("星座：\(zodiacSign)") }
        if !birthday.isEmpty { details.append("生日：\(birthday)") }
        if !birthDetails.isEmpty { details.append("生辰信息：\(birthDetails)") }
        if mbti != "未填写" { details.append("MBTI：\(mbti)") }
        if !speakingStyle.isEmpty { details.append("讲话风格：\(speakingStyle)") }
        if !notes.isEmpty { details.append("补充：\(notes)") }
        return details.joined(separator: "；")
    }
}

struct ChatRoleCard: Identifiable, Codable, Hashable {
    static let maximumNameLength = 16

    let id: UUID
    var name: String
    var relationship: String
    var identity: String
    var userDescription: String
    var zodiacSign: String
    var birthday: String
    var birthDetails: String
    var mbti: String
    var speakingStyle: String
    var notes: String
    var avatarData: Data?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        relationship: String = "朋友",
        identity: String = "",
        userDescription: String = "",
        zodiacSign: String = "未填写",
        birthday: String = "",
        birthDetails: String = "",
        mbti: String = "未填写",
        speakingStyle: String = "",
        notes: String = "",
        avatarData: Data? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maximumNameLength))
        self.relationship = relationship
        self.identity = identity
        self.userDescription = userDescription
        self.zodiacSign = zodiacSign
        self.birthday = birthday
        self.birthDetails = birthDetails
        self.mbti = mbti
        self.speakingStyle = speakingStyle
        self.notes = notes
        self.avatarData = avatarData
        self.updatedAt = updatedAt
    }

    var contextSummary: String {
        var details = ["称呼：\(name)", "与用户的关系：\(relationship)"]
        if !identity.isEmpty { details.append("身份：\(identity)") }
        if !userDescription.isEmpty { details.append("用户描述：\(userDescription)") }
        if zodiacSign != "未填写" { details.append("星座：\(zodiacSign)") }
        if !birthday.isEmpty { details.append("生日：\(birthday)") }
        if !birthDetails.isEmpty { details.append("生辰信息：\(birthDetails)") }
        if mbti != "未填写" { details.append("MBTI：\(mbti)") }
        if !speakingStyle.isEmpty { details.append("讲话风格：\(speakingStyle)") }
        if !notes.isEmpty { details.append("补充：\(notes)") }
        return details.joined(separator: "；")
    }

    var visibleTags: [String] {
        [relationship, identity, zodiacSign == "未填写" ? "" : zodiacSign, mbti == "未填写" ? "" : mbti]
            .filter { !$0.isEmpty }
    }
}

enum AnalysisKind: Hashable {
    case workplace
    case negotiation
    case emotional
    case general
}

struct AnalysisResult: Hashable {
    var kind: AnalysisKind
    var summary: String
    var possibleMeanings: [String]
    var suggestions: [String]
    var roleContext: String?
    var identityContext: String? = nil
}

struct ReplyOption: Identifiable, Hashable {
    let id: UUID
    var label: String
    var text: String
    var rationale: String

    init(id: UUID = UUID(), label: String, text: String, rationale: String) {
        self.id = id
        self.label = label
        self.text = text
        self.rationale = rationale
    }
}

struct AnalysisExchange: Identifiable, Hashable {
    let id: UUID
    /// Exchanges with the same conversation ID are rendered together in the
    /// current chat. A new analysis starts a fresh ID while the sidebar keeps
    /// every completed exchange available under “最近”.
    let conversationID: UUID
    var draft: AnalysisDraft
    var result: AnalysisResult
    var replies: [ReplyOption]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        conversationID: UUID = UUID(),
        draft: AnalysisDraft,
        result: AnalysisResult,
        replies: [ReplyOption],
        createdAt: Date = .now
    ) {
        self.id = id
        self.conversationID = conversationID
        self.draft = draft
        self.result = result
        self.replies = replies
        self.createdAt = createdAt
    }
}

enum ReplyTone: String, CaseIterable, Identifiable {
    case concise
    case gentle
    case direct

    var id: Self { self }

    var title: String {
        switch self {
        case .concise: "更精简"
        case .gentle: "更委婉"
        case .direct: "更明确"
        }
    }

    var systemImage: String {
        switch self {
        case .concise: "text.alignleft"
        case .gentle: "heart"
        case .direct: "arrow.right.circle"
        }
    }
}
