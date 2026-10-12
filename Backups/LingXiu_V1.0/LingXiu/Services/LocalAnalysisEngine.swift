import Foundation

enum LocalAnalysisEngine {
    static func analyze(draft: AnalysisDraft, person: PersonProfile?) -> AnalysisResult {
        let text = draft.conversationText

        if text.contains("价格") || text.contains("降") || draft.relation.contains("客户") {
            return clientResult(person: person)
        }

        if text.contains("没事") || text.contains("不舒服") || draft.relation.contains("恋") {
            return relationshipResult(person: person)
        }

        return workplaceResult(person: person)
    }

    static func generateReplies(goal: String, settings: ReplySettings, result: AnalysisResult) -> [ReplyOption] {
        let actionSuffix = settings.inclusions.contains("完成时间") ? "，今天下午整理一版再同步您确认" : "，整理后再同步您确认"
        let boundaryPrefix = settings.firmness > 0.65 ? "我理解您的关注点，同时建议保留目前有价值的核心方向。" : "收到，我理解您关注的重点。"
        let warmPrefix = settings.warmth > 0.65 ? "谢谢您直接指出这个问题。" : ""

        let recommended = "\(warmPrefix)\(boundaryPrefix)我会先梳理方案结构和关键表达\(actionSuffix)。"
        let proactive = "明白，我重新梳理一下方案逻辑。除了调整现有内容，我也会补充新的思考点，并把主要修改说明一起同步，方便您快速确认。"
        let firm = "我理解您的顾虑。目前核心方向仍有保留价值，我建议不推翻整体方案，先重点优化关键环节，再用两个版本对比确认。"

        let concise = "收到，我会按您关注的重点继续优化\(settings.inclusions.contains("完成时间") ? "，今天下午同步新版" : "")。"
        let first = settings.length == .oneSentence || settings.length == .short ? concise : recommended

        return [
            ReplyOption(label: "最稳妥", text: first),
            ReplyOption(label: "更主动", text: proactive),
            ReplyOption(label: "更坚定", text: firm)
        ]
    }

    static func riskMessages(for text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages: [String] = []

        if trimmed.count < 12 {
            messages.append("回复较短，可能缺少明确的下一步行动。")
        }
        if text.contains("尽量") || text.contains("应该可以") {
            messages.append("承诺范围比较模糊，建议给出更清晰的时间或确认条件。")
        }
        if text.contains("但是") && text.count > 100 {
            messages.append("解释较多，可能被理解为推卸责任；可以先给结论。")
        }
        if text.contains("你必须") || text.contains("不可能") {
            messages.append("立场表达较强，可能增加对抗感。")
        }

        return messages
    }

    private static func workplaceResult(person: PersonProfile?) -> AnalysisResult {
        let nameReference = person.map { "结合与\($0.name)的历史互动，" } ?? ""
        return AnalysisResult(
            summary: "对方更可能是在表达对结果的不满意，同时希望你主动提出下一步方案。",
            surfaceMeaning: "希望你继续优化方案，并拿出更成熟的版本。",
            intentions: [
                Intention(label: "期待明确的修改动作与时间", likelihood: .high, evidence: ["使用“再打磨”“再想想”等行动导向表达", "上下级关系使模糊意见更接近任务要求"]),
                Intention(label: "希望你主动发现问题", likelihood: .medium, evidence: ["没有直接给出具体修改清单", "可能在观察你的判断和主动性"]),
                Intention(label: "只是常规反馈", likelihood: .low, evidence: ["当前上下文不包含明显冲突或否定词"])
            ],
            otherPossibilities: ["对方当时可能比较忙，所以没有展开说明", "反馈可能只针对表达方式，而非整体方向"],
            signals: [
                CommunicationSignal(dimension: "用词", symbol: "text.quote", finding: "表达委婉，但包含继续行动的要求。", evidence: "“再看看”比“重新做”缓和，也保留了调整空间。"),
                CommunicationSignal(dimension: "语气", symbol: "waveform", finding: "正式、克制，负面情绪证据有限。", evidence: "没有使用情绪化词汇，也没有直接否定个人能力。"),
                CommunicationSignal(dimension: "权力关系", symbol: "person.line.dotted.person.fill", finding: "上级的模糊反馈更可能包含执行期待。", evidence: "直属领导通常有任务优先级和验收权。"),
                CommunicationSignal(dimension: "上下文", symbol: "bubble.left.and.text.bubble.right.fill", finding: "当前缺少对方具体标准，适合主动确认。", evidence: "对方没有说明最希望调整的部分。")
            ],
            traits: ["结果导向", "偏好简洁", "重视反馈", "表达克制"],
            expectations: [
                Intention(label: "明确的行动承诺", likelihood: .high, evidence: ["给出修改动作和同步时间能降低不确定性"]),
                Intention(label: "主动判断", likelihood: .medium, evidence: ["对方没有逐条指定修改方式"])
            ],
            relationship: RelationshipState(trust: "稳定", pressure: "中", power: "对方更强", stage: "稳定合作", advice: "\(nameReference)当前不适合强硬反驳。先确认关注点，再提出保留核心方向的优化方案。"),
            risks: [
                RiskNotice(level: "中", message: "解释过多可能显得在推卸责任。"),
                RiskNotice(level: "中", message: "只回复“收到”可能缺少行动感。"),
                RiskNotice(level: "低", message: "当前证据不足，不宜把克制语气理解为强烈不满。")
            ],
            recommendedActions: ["先确认对方最关注的问题", "说明准备采取的修改动作", "给出下一次同步时间", "保留必要的专业判断"]
        )
    }

    private static func clientResult(person: PersonProfile?) -> AnalysisResult {
        AnalysisResult(
            summary: "客户表现出一定兴趣，但正在测试价格空间，并且尚未完成内部决策。",
            surfaceMeaning: "希望获得更低价格，并保留继续比较和讨论的时间。",
            intentions: [
                Intention(label: "争取更优惠的商务条件", likelihood: .high, evidence: ["直接询问降价空间"]),
                Intention(label: "延长内部决策时间", likelihood: .medium, evidence: ["提到仍需内部商量"]),
                Intention(label: "礼貌婉拒", likelihood: .low, evidence: ["仍然针对方案和价格提出具体问题"])
            ],
            otherPossibilities: ["预算确实受限", "客户正在比较其他供应商"],
            signals: [
                CommunicationSignal(dimension: "用词", symbol: "yensign.circle.fill", finding: "讨论已进入条件谈判，而非纯了解阶段。", evidence: "对方把关注点落在价格与决策流程。"),
                CommunicationSignal(dimension: "决策", symbol: "person.3.sequence.fill", finding: "对方可能不是唯一决策者。", evidence: "“内部商量”意味着还需其他人确认。")
            ],
            traits: ["决策谨慎", "关注成本", "保留空间"],
            expectations: [
                Intention(label: "清晰的价格依据", likelihood: .high, evidence: ["解释价值比立即让价更能保持谈判位置"]),
                Intention(label: "有限度的让步", likelihood: .medium, evidence: ["客户已主动测试空间"])
            ],
            relationship: RelationshipState(trust: "建立中", pressure: "中", power: "相对平等", stage: "商务谈判", advice: "先确认预算与决策条件，再决定是否用范围、付款方式或交付内容交换让步。"),
            risks: [
                RiskNotice(level: "中", message: "立即降价会削弱后续谈判位置。"),
                RiskNotice(level: "低", message: "过度催促可能给客户增加决策压力。")
            ],
            recommendedActions: ["确认客户预算与决策时间", "重申方案价值", "用条件交换让步", "约定下一次跟进节点"]
        )
    }

    private static func relationshipResult(person: PersonProfile?) -> AnalysisResult {
        AnalysisResult(
            summary: "对方可能有情绪或希望被关注，但仅凭这句话无法确定，需要结合前因和后续反应。",
            surfaceMeaning: "对方表示事情不严重，允许你先处理自己的安排。",
            intentions: [
                Intention(label: "希望获得关心或解释", likelihood: .medium, evidence: ["表达较短，可能在压低直接需求"]),
                Intention(label: "确实想暂停沟通", likelihood: .medium, evidence: ["字面上明确提出“你忙你的”"]),
                Intention(label: "强烈生气", likelihood: .low, evidence: ["缺少更多上下文和行为证据"])
            ],
            otherPossibilities: ["对方当时只是疲惫", "对方希望稍后再谈"],
            signals: [
                CommunicationSignal(dimension: "语气", symbol: "ellipsis.bubble.fill", finding: "简短表达增加了多种解释的可能。", evidence: "不能仅凭“没事”判断为反话。"),
                CommunicationSignal(dimension: "上下文", symbol: "questionmark.bubble.fill", finding: "需要了解此前是否有承诺或忽略。", evidence: "前因会显著改变这句话的含义。")
            ],
            traits: ["信息不足", "可能需要情绪确认", "避免过度解读"],
            expectations: [
                Intention(label: "被看见和确认", likelihood: .medium, evidence: ["可以用低压力问题确认状态"]),
                Intention(label: "获得空间", likelihood: .medium, evidence: ["对方也可能真的希望暂停"])
            ],
            relationship: RelationshipState(trust: "建立中", pressure: "中", power: "相对平等", stage: "轻微摩擦", advice: "先表达关注并提供选择，不逼迫对方立即解释，也不要直接认定对方在说反话。"),
            risks: [
                RiskNotice(level: "中", message: "直接说“你就是生气了”可能让对方感到被定义。"),
                RiskNotice(level: "低", message: "完全不回应可能错过修复关系的机会。")
            ],
            recommendedActions: ["表达关注", "用开放问题确认", "允许对方稍后再说", "避免连续追问"]
        )
    }
}
