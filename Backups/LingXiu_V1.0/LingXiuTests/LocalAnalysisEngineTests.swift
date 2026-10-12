import XCTest
@testable import LingXiu

@MainActor
final class LocalAnalysisEngineTests: XCTestCase {
    func testWorkplaceAnalysisUsesProbabilisticLanguage() {
        var draft = AnalysisDraft(inputMode: .text)
        draft.conversationText = "领导：这个方案还需要再打磨一下，你再多想想。"
        draft.relation = "直属领导"

        let result = LocalAnalysisEngine.analyze(draft: draft, person: nil)

        XCTAssertTrue(result.summary.contains("更可能"))
        XCTAssertEqual(result.intentions.first?.likelihood, .high)
        XCTAssertFalse(result.signals.isEmpty)
        XCTAssertFalse(result.risks.isEmpty)
    }

    func testClientAnalysisRecognizesPriceNegotiation() {
        var draft = AnalysisDraft(inputMode: .text)
        draft.conversationText = "客户：价格能不能再降一点？我们还要内部商量。"
        draft.relation = "客户"

        let result = LocalAnalysisEngine.analyze(draft: draft, person: nil)

        XCTAssertTrue(result.summary.contains("价格空间"))
        XCTAssertTrue(result.recommendedActions.contains("确认客户预算与决策时间"))
    }

    func testRelationshipAnalysisAvoidsMindReading() {
        var draft = AnalysisDraft(inputMode: .text)
        draft.conversationText = "对方：没事，你忙你的吧。"
        draft.relation = "恋人"

        let result = LocalAnalysisEngine.analyze(draft: draft, person: nil)

        XCTAssertTrue(result.summary.contains("无法确定"))
        XCTAssertTrue(result.risks.contains { $0.message.contains("被定义") })
    }

    func testReplyGeneratorCreatesDistinctOptions() {
        var draft = AnalysisDraft(inputMode: .text)
        draft.conversationText = "这个方案再优化一下。"
        let result = LocalAnalysisEngine.analyze(draft: draft, person: nil)

        let replies = LocalAnalysisEngine.generateReplies(
            goal: "部分接受",
            settings: ReplySettings(),
            result: result
        )

        XCTAssertEqual(replies.count, 3)
        XCTAssertEqual(Set(replies.map(\.text)).count, 3)
        XCTAssertEqual(replies.first?.label, "最稳妥")
    }

    func testRiskDetectorFlagsShortPassiveReply() {
        let risks = LocalAnalysisEngine.riskMessages(for: "好的。")
        XCTAssertTrue(risks.contains { $0.contains("回复较短") })
    }
}
