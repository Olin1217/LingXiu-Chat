import XCTest
@testable import LingXiu

@MainActor
final class LocalAnalysisEngineTests: XCTestCase {
    func testWorkplaceAnalysisUsesProbabilisticLanguage() {
        let draft = AnalysisDraft(conversationText: "领导：这个方案还需要再打磨一下，你再多想想。")

        let result = LocalAnalysisEngine.analyze(draft: draft, roleCard: nil)

        XCTAssertEqual(result.kind, .workplace)
        XCTAssertTrue(result.summary.contains("更可能"))
        XCTAssertFalse(result.possibleMeanings.isEmpty)
        XCTAssertFalse(result.suggestions.isEmpty)
    }

    func testNegotiationAnalysisRecognizesPriceQuestion() {
        let draft = AnalysisDraft(conversationText: "客户：价格能不能再降一点？我们还要内部商量。")

        let result = LocalAnalysisEngine.analyze(draft: draft, roleCard: nil)

        XCTAssertEqual(result.kind, .negotiation)
        XCTAssertTrue(result.summary.contains("价格空间"))
        XCTAssertTrue(result.suggestions.contains { $0.contains("预算") })
    }

    func testEmotionalAnalysisAvoidsMindReading() {
        let draft = AnalysisDraft(conversationText: "对方：没事，你忙你的吧。")

        let result = LocalAnalysisEngine.analyze(draft: draft, roleCard: nil)

        XCTAssertEqual(result.kind, .emotional)
        XCTAssertTrue(result.summary.contains("无法确定"))
        XCTAssertTrue(result.suggestions.contains { $0.contains("不直接定义") })
    }

    func testReplyGeneratorReturnsThreeDistinctOptions() {
        let draft = AnalysisDraft(conversationText: "这个方案再优化一下。")
        let result = LocalAnalysisEngine.analyze(draft: draft, roleCard: nil)

        let replies = LocalAnalysisEngine.generateReplies(result: result, roleCard: nil)

        XCTAssertEqual(replies.count, 3)
        XCTAssertEqual(Set(replies.map(\.text)).count, 3)
        XCTAssertFalse(replies.contains { $0.rationale.isEmpty })
    }

    func testRoleCardContextAffectsAnalysisAndReplyTone() {
        let leader = ChatRoleCard(
            name: "王总",
            relationship: "直属领导",
            identity: "部门负责人",
            userDescription: "重视结果，不喜欢长篇解释",
            zodiacSign: "摩羯座",
            birthday: "1 月 8 日",
            birthDetails: "上午出生",
            mbti: "INTJ",
            speakingStyle: "简洁直接"
        )
        let draft = AnalysisDraft(conversationText: "这件事你再看看。", selectedRoleCardID: leader.id)

        let result = LocalAnalysisEngine.analyze(draft: draft, roleCard: leader)
        let replies = LocalAnalysisEngine.generateReplies(result: result, roleCard: leader)

        XCTAssertEqual(result.kind, .workplace)
        XCTAssertTrue(result.roleContext?.contains("MBTI：INTJ") == true)
        XCTAssertTrue(result.suggestions.contains { $0.contains("先说结论") })
        XCTAssertTrue(replies.first?.text.contains("您") == true)
    }

    func testRoleCardContextIncludesOptionalProfileFields() {
        let card = ChatRoleCard(
            name: "小林",
            relationship: "朋友",
            userDescription: "说话委婉",
            zodiacSign: "双鱼座",
            birthday: "3 月 2 日",
            birthDetails: "晚上 9 点",
            mbti: "INFP",
            speakingStyle: "倾向先表达感受"
        )

        XCTAssertTrue(card.contextSummary.contains("星座：双鱼座"))
        XCTAssertTrue(card.contextSummary.contains("生辰信息：晚上 9 点"))
        XCTAssertTrue(card.contextSummary.contains("讲话风格：倾向先表达感受"))
    }
}
