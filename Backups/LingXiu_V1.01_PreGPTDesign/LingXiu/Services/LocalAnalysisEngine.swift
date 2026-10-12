import Foundation

enum LocalAnalysisEngine {
    static func analyze(draft: AnalysisDraft, roleCard: ChatRoleCard?) -> AnalysisResult {
        let text = draft.conversationText.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = detectKind(in: text, roleCard: roleCard)
        let base = baseAnalysis(for: kind)
        var suggestions: [String] = []

        if let roleCard {
            suggestions.append(contentsOf: roleAwareSuggestions(for: roleCard))
        }
        suggestions.append(contentsOf: base.suggestions)

        return AnalysisResult(
            kind: kind,
            summary: base.summary,
            possibleMeanings: base.possibleMeanings,
            suggestions: Array(suggestions.uniqued().prefix(4)),
            roleContext: roleCard?.contextSummary
        )
    }

    static func generateReplies(result: AnalysisResult, roleCard: ChatRoleCard?) -> [ReplyOption] {
        let honorific = shouldUseHonorific(for: roleCard)
        let you = honorific ? "您" : "你"

        return switch result.kind {
        case .workplace:
            [
                ReplyOption(
                    label: "稳妥执行",
                    text: "收到，我先按\(you)提到的方向梳理重点，今天整理好修改方案和时间节点后再同步\(you)确认。",
                    rationale: "先确认收到，再给出行动和反馈时间。"
                ),
                ReplyOption(
                    label: "主动确认",
                    text: "收到。为了避免方向偏差，我想先确认一下：这次最需要优先调整的是内容逻辑、表达方式，还是最终结果？",
                    rationale: "适合要求比较模糊、需要补充标准时使用。"
                ),
                ReplyOption(
                    label: "说明边界",
                    text: "可以，我会继续优化。目前时间比较紧，我先完成最关键的部分，其他调整预计需要到明天，\(you)看这样安排是否合适？",
                    rationale: "接受任务的同时说明现实时间限制。"
                )
            ]
        case .negotiation:
            [
                ReplyOption(
                    label: "保留空间",
                    text: "理解\(you)对预算的考虑。我们可以先确认最重要的交付范围，再看看价格和方案怎样调整更匹配。",
                    rationale: "不立即降价，先确认真正的预算与需求。"
                ),
                ReplyOption(
                    label: "交换条件",
                    text: "价格可以继续讨论。如果交付范围、付款方式或合作周期能够一起确认，我们可以再给\(you)一个更合适的方案。",
                    rationale: "把价格让步和明确条件绑定。"
                ),
                ReplyOption(
                    label: "推进决策",
                    text: "没问题。方便的话，也请\(you)告诉我内部主要还在评估哪些点，以及预计什么时候能有结论，我好针对性准备。",
                    rationale: "温和确认决策障碍和下一步时间。"
                )
            ]
        case .emotional:
            [
                ReplyOption(
                    label: "先接住情绪",
                    text: "我感觉\(you)可能有些不舒服。如果我刚才哪里让\(you)觉得被忽略了，可以告诉我，我想认真听听。",
                    rationale: "表达关心，但不替对方下结论。"
                ),
                ReplyOption(
                    label: "温和确认",
                    text: "我不太确定自己有没有理解对。\(you)是想先安静一下，还是希望我们现在把这件事聊清楚？",
                    rationale: "给对方选择，降低追问压力。"
                ),
                ReplyOption(
                    label: "尊重空间",
                    text: "好，我先不打扰\(you)。如果\(you)之后想聊，我在；这件事对我也很重要。",
                    rationale: "适合对方暂时不想继续沟通时使用。"
                )
            ]
        case .general:
            [
                ReplyOption(
                    label: "稳妥回应",
                    text: "收到，我理解\(you)的意思了。我先处理一下，稍后把结果和下一步同步给\(you)。",
                    rationale: "适合信息明确、需要快速确认的场景。"
                ),
                ReplyOption(
                    label: "确认理解",
                    text: "我确认一下，\(you)更希望我现在直接处理，还是先把几个可选方案整理出来再一起决定？",
                    rationale: "信息不足时先降低误解风险。"
                ),
                ReplyOption(
                    label: "保留边界",
                    text: "这件事我可以配合，不过需要先确认范围和时间。我们把最重要的部分定下来，我再给\(you)一个明确答复。",
                    rationale: "避免在条件不清楚时过度承诺。"
                )
            ]
        }
    }

    private static func detectKind(in text: String, roleCard: ChatRoleCard?) -> AnalysisKind {
        let combined = [text, roleCard?.relationship ?? "", roleCard?.identity ?? ""]
            .joined(separator: " ")
            .lowercased()

        if combined.contains("价格") || combined.contains("预算") || combined.contains("报价") || combined.contains("降一点") {
            return .negotiation
        }
        if combined.contains("领导") || combined.contains("老板") || combined.contains("上级") || combined.contains("方案") || combined.contains("汇报") {
            return .workplace
        }
        if combined.contains("没事") || combined.contains("随便") || combined.contains("你忙") || combined.contains("不舒服") || combined.contains("算了") {
            return .emotional
        }
        return .general
    }

    private static func baseAnalysis(for kind: AnalysisKind) -> (summary: String, possibleMeanings: [String], suggestions: [String]) {
        switch kind {
        case .workplace:
            return (
                "对方更可能是在表达对当前结果仍有保留，并期待你给出明确的改进动作。具体标准仍需要进一步确认。",
                ["希望继续修改，而不是立即结束讨论", "可能在观察你能否主动识别重点", "也可能只是反馈比较简略，信息仍不完整"],
                ["先确认收到，再说明下一步动作", "对模糊要求补问优先级或判断标准", "给出明确的反馈时间"]
            )
        case .negotiation:
            return (
                "对方已经表现出一定兴趣，同时可能在测试价格空间或等待内部意见。当前还不能直接判断为接受或拒绝。",
                ["确实存在预算压力", "正在比较其他方案", "希望通过议价获得更多价值", "内部决策人尚未达成一致"],
                ["确认预算、决策人和预计时间", "用范围或合作条件交换价格让步", "约定下一次跟进节点"]
            )
        case .emotional:
            return (
                "这段表达可能带有失落、不满或暂时回避，但仅凭一句话无法确定真实情绪，需要结合前后文继续确认。",
                ["可能希望你主动关注情绪", "可能暂时不想继续争论", "也可能只是当时忙碌或表达习惯简短"],
                ["先表达关心，不直接定义对方情绪", "用可选择的问题确认对方需求", "必要时给对方一点空间"]
            )
        case .general:
            return (
                "目前信息更像是在传递一个需要回应或继续确认的事项。上下文有限，建议先核对理解，再决定承诺程度。",
                ["对方希望尽快得到明确回应", "双方对范围或时间的理解可能不同", "语气本身未必代表态度，需要结合关系判断"],
                ["复述你的理解并请对方确认", "区分事实、推测和你的感受", "没有把握时避免一次性过度承诺"]
            )
        }
    }

    private static func roleAwareSuggestions(for roleCard: ChatRoleCard) -> [String] {
        var suggestions: [String] = []
        let relation = roleCard.relationship
        let style = roleCard.speakingStyle + roleCard.userDescription

        if relation.contains("领导") || relation.contains("老板") || relation.contains("上级") {
            suggestions.append("面对上级时优先给结论、行动和时间点")
        }
        if style.contains("直接") || style.contains("简洁") || style.contains("结果") {
            suggestions.append("角色卡显示对方偏好直接表达，回复可先说结论")
        }
        if style.contains("敏感") || style.contains("委婉") || style.contains("情绪") {
            suggestions.append("角色卡显示对方更在意表达方式，先确认感受再讨论方案")
        }
        return suggestions
    }

    private static func shouldUseHonorific(for roleCard: ChatRoleCard?) -> Bool {
        guard let roleCard else { return false }
        let relation = roleCard.relationship
        return relation.contains("领导") || relation.contains("老板") || relation.contains("上级") || relation.contains("客户") || relation.contains("长辈")
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
