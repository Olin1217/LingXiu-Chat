import Foundation

enum AppTab: Hashable {
    case analysis
    case roleCards
}

struct AnalysisDraft: Hashable {
    var conversationText = ""
    var imageData: [Data] = []
    var selectedRoleCardID: UUID?

    var hasUsableText: Bool {
        !conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct ChatRoleCard: Identifiable, Codable, Hashable {
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
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.identity = identity
        self.userDescription = userDescription
        self.zodiacSign = zodiacSign
        self.birthday = birthday
        self.birthDetails = birthDetails
        self.mbti = mbti
        self.speakingStyle = speakingStyle
        self.notes = notes
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
