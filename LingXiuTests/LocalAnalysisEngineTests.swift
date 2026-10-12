import Security
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

    func testIdentityCardContextParticipatesInAnalysis() {
        let identity = IdentityCard(
            name: "工作中的我",
            identity: "职场新人",
            userDescription: "希望表达稳妥清晰",
            speakingStyle: "温和委婉"
        )
        let draft = AnalysisDraft(
            conversationText: "领导说：这个方案你再想想。",
            selectedIdentityCardID: identity.id
        )

        let result = LocalAnalysisEngine.analyze(
            draft: draft,
            roleCard: nil,
            identityCard: identity
        )

        XCTAssertTrue(result.identityContext?.contains("职场新人") == true)
        XCTAssertTrue(result.suggestions.contains { $0.contains("你的身份") })
    }

    func testSubmittingDraftCreatesConversationExchangeAndKeepsSelectedRole() async {
        let store = AppStore(persistsChanges: false)
        let leader = ChatRoleCard(
            name: "王总",
            relationship: "领导",
            speakingStyle: "简洁直接"
        )
        store.saveRoleCard(leader)
        store.draft = AnalysisDraft(
            conversationText: "这个方案你再想想。",
            selectedRoleCardID: leader.id,
            quickTopic: .dealingWithLeader
        )

        let submitted = await store.runAnalysis()

        XCTAssertTrue(submitted)
        XCTAssertEqual(store.exchanges.count, 1)
        XCTAssertEqual(store.exchanges.first?.draft.conversationText, "这个方案你再想想。")
        XCTAssertEqual(store.exchanges.first?.draft.quickTopic, .dealingWithLeader)
        XCTAssertEqual(store.exchanges.first?.replies.count, 3)
        XCTAssertEqual(store.draft.selectedRoleCardID, leader.id)
        XCTAssertNil(store.draft.quickTopic)
        XCTAssertTrue(store.draft.conversationText.isEmpty)
    }

    func testNewAnalysisStartsFreshChatAndKeepsRecentHistory() async {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "第一段沟通"
        let firstSubmitted = await store.runAnalysis()
        XCTAssertTrue(firstSubmitted)
        let firstConversation = store.currentConversationID
        let firstExchange = try! XCTUnwrap(store.exchanges.first)

        store.beginNewConversation()

        XCTAssertNotEqual(store.currentConversationID, firstConversation)
        XCTAssertTrue(store.currentExchanges.isEmpty)
        XCTAssertEqual(store.exchanges.count, 1)
        XCTAssertEqual(firstExchange.conversationID, firstConversation)

        store.draft.conversationText = "第二段沟通"
        let secondSubmitted = await store.runAnalysis()
        XCTAssertTrue(secondSubmitted)
        XCTAssertEqual(store.currentExchanges.count, 1)
        XCTAssertEqual(store.exchanges.count, 2)
    }

    func testClearingCurrentConversationDoesNotDeleteRecentChats() async {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "旧聊天"
        let oldSubmitted = await store.runAnalysis()
        XCTAssertTrue(oldSubmitted)
        store.beginNewConversation()
        store.draft.conversationText = "当前聊天"
        let currentSubmitted = await store.runAnalysis()
        XCTAssertTrue(currentSubmitted)

        store.clearConversation()

        XCTAssertTrue(store.currentExchanges.isEmpty)
        XCTAssertEqual(store.exchanges.count, 1)
        XCTAssertEqual(store.exchanges.first?.draft.conversationText, "旧聊天")
    }

    func testRoleAndIdentityNamesAreLimitedGlobally() {
        let longName = String(repeating: "人", count: 40)
        XCTAssertEqual(ChatRoleCard(name: longName).name.count, ChatRoleCard.maximumNameLength)
        XCTAssertEqual(IdentityCard(name: longName).name.count, IdentityCard.maximumNameLength)

        let store = AppStore(persistsChanges: false)
        store.saveRoleCard(ChatRoleCard(name: longName))
        store.saveIdentityCard(IdentityCard(name: longName))
        XCTAssertEqual(store.roleCards.first?.name.count, ChatRoleCard.maximumNameLength)
        XCTAssertEqual(store.identityCards.first?.name.count, IdentityCard.maximumNameLength)
    }

    func testArkConfigurationNeverTreatsPlaceholderAsAKey() {
        let configuration = ArkAIConfiguration(apiKey: "<ARK_API_KEY>")
        XCTAssertFalse(configuration.isConfigured)
        XCTAssertEqual(configuration.modelID, "doubao-seed-evolving")
        XCTAssertEqual(configuration.endpointURL.absoluteString, "https://ark.cn-beijing.volces.com/api/v3/responses")
    }

    func testArkServerProxyConfigurationSupportsASeparateRotatableToken() {
        let endpoint = URL(string: "https://api.lingxiu.example/v1/responses")!
        let configuration = ArkAIConfiguration(
            proxyToken: "temporary-app-token",
            pinnedCertificateSHA256: "5A:1A:88:A7:40:71:8C:9F:FD:DE:2F:F8:81:76:AF:DA:E6:14:71:F1:F1:07:BB:E1:37:D8:34:2F:23:C4:7B:3C",
            endpointURL: endpoint,
            transport: .serverProxy
        )

        XCTAssertTrue(configuration.isConfigured)
        XCTAssertTrue(configuration.usesServerProxy)
        XCTAssertNil(configuration.apiKey)
        XCTAssertEqual(configuration.proxyToken, "temporary-app-token")
        XCTAssertEqual(
            configuration.pinnedCertificateSHA256,
            "5a1a88a740718c9ffdde2ff88176afdae61471f1f107bbe137d8342f23c47b3c"
        )
        XCTAssertEqual(configuration.endpointURL, endpoint)
    }

    func testInvalidCertificateFingerprintIsIgnored() {
        let configuration = ArkAIConfiguration(
            pinnedCertificateSHA256: "not-a-certificate-fingerprint"
        )

        XCTAssertNil(configuration.pinnedCertificateSHA256)
    }

    func testBundledDevelopmentCAIsAValidCertificate() throws {
        let data = try XCTUnwrap(
            PinnedCertificateURLSessionDelegate.bundledDevelopmentCAData()
        )
        XCTAssertNotNil(SecCertificateCreateWithData(nil, data as CFData))
    }

    func testArkNetworkErrorsUseActionableMessages() {
        XCTAssertEqual(
            ArkAIService.networkError(for: .serverCertificateUntrusted).errorDescription,
            "安全连接验证失败，请更新灵嗅或联系开发者"
        )
        XCTAssertEqual(
            ArkAIService.networkError(for: .notConnectedToInternet).errorDescription,
            "当前网络不可用，请检查网络连接后重试"
        )
        XCTAssertEqual(
            ArkAIService.networkError(for: .timedOut).errorDescription,
            "云端 AI 响应超时，请稍后重试"
        )
        XCTAssertEqual(
            ArkAIService.networkError(for: .badServerResponse).errorDescription,
            "暂时无法连接云端 AI，请稍后重试"
        )
    }

    func testArkProxyRoundTripWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["LINGXIU_RUN_ARK_INTEGRATION"] == "1" else {
            throw XCTSkip("Ark proxy integration test is opt-in")
        }
        let endpoint = try XCTUnwrap(
            environment["LINGXIU_AI_ENDPOINT"].flatMap(URL.init(string:))
        )
        let proxyToken = try XCTUnwrap(environment["LINGXIU_PROXY_TOKEN"])
        let certificatePin = try XCTUnwrap(
            environment["LINGXIU_PINNED_CERTIFICATE_SHA256"]
        )
        let service = ArkAIService(configuration: ArkAIConfiguration(
            proxyToken: proxyToken,
            pinnedCertificateSHA256: certificatePin,
            endpointURL: endpoint,
            transport: .serverProxy
        ))

        let payload = try await service.analyze(
            draft: AnalysisDraft(conversationText: "联调证书与代理连接"),
            roleCard: nil,
            identityCard: nil,
            fallbackKind: .general
        )
        XCTAssertFalse(payload.result.summary.isEmpty)
        XCTAssertFalse(payload.replies.isEmpty)
    }

    func testArkResponsesParserPrefersAssistantOutputOverReasoningSummary() throws {
        let response = """
        {
          "output": [
            {
              "type": "reasoning",
              "content": [{"type": "summary_text", "text": "内部推理不应展示"}]
            },
            {
              "type": "message",
              "content": [{"type": "output_text", "text": "{\\"summary\\":\\"可展示结果\\"}"}]
            }
          ]
        }
        """

        let output = try ArkAIService.extractOutputText(from: Data(response.utf8))

        XCTAssertEqual(output, #"{"summary":"可展示结果"}"#)
    }

    func testArkJSONExtractionDropsMarkdownAndTrailingText() throws {
        let output = "说明文字\n```json\n{\"summary\":\"结果\"}\n```\n无关尾注"
        let data = try XCTUnwrap(ArkAIService.firstJSONObject(in: output))

        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"summary":"结果"}"#)
    }

    func testQuickTopicParticipatesInAnalysisContextButCannotSubmitAlone() {
        let topicOnlyDraft = AnalysisDraft(quickTopic: .salaryNegotiation)

        XCTAssertFalse(topicOnlyDraft.hasUsableText)
        XCTAssertEqual(topicOnlyDraft.effectiveConversationText, "沟通主题：谈薪加薪\n")

        let completeDraft = AnalysisDraft(
            conversationText: "我想和主管谈一下调薪。",
            quickTopic: .salaryNegotiation
        )
        XCTAssertTrue(completeDraft.hasUsableText)
        XCTAssertTrue(completeDraft.effectiveConversationText.hasPrefix("沟通主题：谈薪加薪\n"))
    }

    func testSelectingAnotherQuickTopicReplacesTheCurrentTopic() async {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "请帮我看看怎么回复"

        store.selectQuickTopic(.dealingWithLeader)
        store.selectQuickTopic(.politeRefusal)

        XCTAssertEqual(store.draft.quickTopic, .politeRefusal)
        XCTAssertEqual(store.draft.conversationText, "请帮我看看怎么回复")
        await Task.yield()
    }

    func testSwitchingRoleCardClearsQuickTopicButKeepsTypedContent() async {
        let store = AppStore(persistsChanges: false)
        let leader = ChatRoleCard(name: "王总", relationship: "领导")
        let colleague = ChatRoleCard(name: "小林", relationship: "同事")
        store.saveRoleCard(leader)
        store.saveRoleCard(colleague)
        store.selectRoleCard(id: leader.id)
        store.draft.conversationText = "我该怎么回复？"
        store.selectQuickTopic(.dealingWithLeader)

        store.selectRoleCard(id: colleague.id)

        XCTAssertEqual(store.draft.selectedRoleCardID, colleague.id)
        XCTAssertNil(store.draft.quickTopic)
        XCTAssertEqual(store.draft.conversationText, "我该怎么回复？")
        await Task.yield()
    }

    func testSelectingTheSameRoleCardDoesNotDiscardQuickTopic() async {
        let store = AppStore(persistsChanges: false)
        let leader = ChatRoleCard(name: "王总", relationship: "领导")
        store.saveRoleCard(leader)
        store.selectRoleCard(id: leader.id)
        store.selectQuickTopic(.dealingWithLeader)

        store.selectRoleCard(id: leader.id)

        XCTAssertEqual(store.draft.quickTopic, .dealingWithLeader)
        await Task.yield()
    }

    func testSwitchingIdentityCardClearsQuickTopic() async {
        let store = AppStore(persistsChanges: false)
        let workIdentity = IdentityCard(name: "工作中的我")
        let familyIdentity = IdentityCard(name: "家庭中的我")
        store.saveIdentityCard(workIdentity)
        store.saveIdentityCard(familyIdentity)
        store.selectIdentityCard(id: workIdentity.id)
        store.selectQuickTopic(.familyCommunication)

        store.selectIdentityCard(id: familyIdentity.id)

        XCTAssertEqual(store.draft.selectedIdentityCardID, familyIdentity.id)
        XCTAssertNil(store.draft.quickTopic)
        await Task.yield()
    }

    func testBackspaceAtInputStartDeletesQuickTopicAsOneToken() {
        let textView = BackspaceAwareTextView()
        var deletedToken = false
        textView.text = ""
        textView.selectedRange = NSRange(location: 0, length: 0)
        textView.onDeleteBackwardAtStart = {
            deletedToken = true
        }

        textView.deleteBackward()

        XCTAssertTrue(deletedToken)
        XCTAssertEqual(textView.text, "")
    }

    func testBackspaceDeletesTypedTextBeforeQuickTopicToken() {
        let textView = BackspaceAwareTextView()
        var deletedToken = false
        textView.text = "A"
        textView.selectedRange = NSRange(location: 1, length: 0)
        textView.onDeleteBackwardAtStart = {
            deletedToken = true
        }

        textView.deleteBackward()

        XCTAssertEqual(textView.text, "")
        XCTAssertFalse(deletedToken)

        textView.deleteBackward()

        XCTAssertTrue(deletedToken)
    }

    func testComposerExplicitFocusRequestAlwaysPublishesFocusIntent() {
        let textView = BackspaceAwareTextView()
        var requestedFocus = false
        textView.onFocusRequest = {
            requestedFocus = true
        }

        let becameFirstResponder = textView.requestInputFocus()

        XCTAssertTrue(requestedFocus)
        XCTAssertFalse(becameFirstResponder, "未加入窗口的文本框不应错误报告为第一响应者")
    }

    func testComposerStaysCompactForShortSingleLineText() {
        XCTAssertFalse(
            ComposerLayoutPolicy.requiresMultiline(
                text: "测试一行文字",
                compactWidth: 210
            )
        )
    }

    func testComposerUsesExpandedCardAsSoonAsInputIsFocused() {
        XCTAssertTrue(
            ComposerLayoutPolicy.usesExpandedCard(
                isFocused: true,
                text: "",
                compactWidth: 210
            )
        )
        XCTAssertTrue(
            ComposerLayoutPolicy.usesExpandedCard(
                isFocused: true,
                text: "第一行",
                compactWidth: 210
            )
        )
        XCTAssertFalse(
            ComposerLayoutPolicy.usesExpandedCard(
                isFocused: false,
                text: "",
                compactWidth: 210
            )
        )
    }

    func testComposerPlaceholderDisappearsWhenInputIsFocused() {
        XCTAssertTrue(
            ComposerLayoutPolicy.showsPlaceholder(
                text: "",
                placeholder: "粘贴聊天内容或描述场景",
                isFocused: false
            )
        )
        XCTAssertFalse(
            ComposerLayoutPolicy.showsPlaceholder(
                text: "",
                placeholder: "粘贴聊天内容或描述场景",
                isFocused: true
            )
        )
        XCTAssertFalse(
            ComposerLayoutPolicy.showsPlaceholder(
                text: "已经输入内容",
                placeholder: "粘贴聊天内容或描述场景",
                isFocused: false
            )
        )
    }

    func testQuickTopicExclusionEndsAfterFirstInputLine() {
        let textView = BackspaceAwareTextView(usingTextLayoutManager: false)
        textView.frame = CGRect(x: 0, y: 0, width: 260, height: 120)
        textView.font = .preferredFont(forTextStyle: .body)
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.text = "第一行输入\n第二行输入"

        let tokenHeight = ComposerLayoutPolicy.inlineTokenHeight(font: textView.font!)
        textView.textContainer.exclusionPaths = [
            UIBezierPath(
                roundedRect: CGRect(x: 0, y: 0, width: 92, height: tokenHeight),
                cornerRadius: 8
            )
        ]
        textView.layoutManager.ensureLayout(for: textView.textContainer)

        var lineOrigins: [CGFloat] = []
        textView.layoutManager.enumerateLineFragments(
            forGlyphRange: NSRange(location: 0, length: textView.layoutManager.numberOfGlyphs)
        ) { _, usedRect, _, _, _ in
            lineOrigins.append(usedRect.minX)
        }

        XCTAssertGreaterThanOrEqual(lineOrigins.count, 2)
        XCTAssertGreaterThan(lineOrigins[0], 40)
        XCTAssertEqual(lineOrigins[1], 0, accuracy: 0.5)
    }

    func testComposerGrowsForLineBreakAndReturnsToCompactAfterDeletion() {
        XCTAssertTrue(
            ComposerLayoutPolicy.requiresMultiline(
                text: "第一行\n第二行",
                compactWidth: 210
            )
        )
        XCTAssertFalse(
            ComposerLayoutPolicy.requiresMultiline(
                text: "第一行",
                compactWidth: 210
            )
        )
    }

    func testComposerExpansionControlAppearsAtFiveLinesOrWhenScrollable() {
        XCTAssertFalse(
            ComposerLayoutPolicy.showsExpansionControl(
                for: ComposerTextMetrics(contentHeight: 88, lineCount: 4)
            )
        )
        XCTAssertTrue(
            ComposerLayoutPolicy.showsExpansionControl(
                for: ComposerTextMetrics(contentHeight: 110, lineCount: 5)
            )
        )
        XCTAssertTrue(
            ComposerLayoutPolicy.showsExpansionControl(
                for: ComposerTextMetrics(contentHeight: 198, lineCount: 9, isVerticallyScrollable: true)
            )
        )
    }

    func testQuickTopicsKeepProductOrderAndCompleteCount() {
        XCTAssertEqual(
            QuickTopic.allCases.map(\.rawValue),
            [
                "应对领导", "沟通导师", "同事相处", "礼貌拒绝", "表达不满", "催促进度",
                "道歉解释", "提出请求", "争取机会", "谈薪加薪", "恋爱沟通", "暧昧判断",
                "缓和矛盾", "朋友相处", "家庭沟通", "设立边界", "判断态度", "识别试探"
            ]
        )
    }

    func testQuickTopicAndOptimizationModesCannotRemainActiveTogether() async {
        let store = AppStore(persistsChanges: false)

        store.selectQuickTopic(.dealingWithLeader)
        store.beginOptimization(for: "原回复")

        XCTAssertNil(store.draft.quickTopic)
        XCTAssertEqual(store.draft.optimizationQuote, "原回复")

        store.selectQuickTopic(.politeRefusal)

        XCTAssertEqual(store.draft.quickTopic, .politeRefusal)
        XCTAssertNil(store.draft.optimizationQuote)
        await Task.yield()
    }

    func testRestoringExchangeRestoresQuickTopic() async throws {
        let store = AppStore(persistsChanges: false)
        store.draft = AnalysisDraft(
            conversationText: "这件事我该怎样礼貌拒绝？",
            quickTopic: .politeRefusal
        )
        _ = await store.runAnalysis()
        let exchange = try XCTUnwrap(store.exchanges.first)

        store.restoreDraft(from: exchange)

        XCTAssertEqual(store.draft.quickTopic, .politeRefusal)
        XCTAssertEqual(store.draft.conversationText, "这件事我该怎样礼貌拒绝？")
    }

    func testReplyCanBeRewrittenInsideConversation() async throws {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "客户问：价格能不能再降一点？"
        _ = await store.runAnalysis()

        let exchange = try XCTUnwrap(store.exchanges.first)
        let reply = try XCTUnwrap(exchange.replies.first)
        store.rewriteReply(exchangeID: exchange.id, replyID: reply.id, tone: .direct)

        XCTAssertTrue(store.exchanges[0].replies[0].text.hasPrefix("我直接说明一下："))
        XCTAssertTrue(store.exchanges[0].replies[0].rationale.contains("更明确"))
    }

    func testNewConversationClearsMessagesButRetainsRoleCardSelection() async {
        let store = AppStore(persistsChanges: false)
        let friend = ChatRoleCard(name: "小林", relationship: "朋友")
        store.saveRoleCard(friend)
        store.draft = AnalysisDraft(conversationText: "随便，你看着办。", selectedRoleCardID: friend.id)
        _ = await store.runAnalysis()

        store.clearConversation()

        XCTAssertTrue(store.currentExchanges.isEmpty)
        XCTAssertEqual(store.exchanges.count, 1)
        XCTAssertNil(store.result)
        XCTAssertEqual(store.draft.selectedRoleCardID, friend.id)
        XCTAssertNil(store.draft.quickTopic)
        XCTAssertTrue(store.draft.conversationText.isEmpty)
    }

    func testNewConversationRetainsIdentityCardSelection() async {
        let store = AppStore(persistsChanges: false)
        let identity = IdentityCard(name: "工作中的我", identity: "产品经理")
        store.saveIdentityCard(identity)
        store.draft = AnalysisDraft(
            conversationText: "客户说：价格再考虑一下。",
            selectedIdentityCardID: identity.id
        )
        _ = await store.runAnalysis()

        store.clearConversation()

        XCTAssertEqual(store.draft.selectedIdentityCardID, identity.id)
        XCTAssertTrue(store.currentExchanges.isEmpty)
        XCTAssertEqual(store.exchanges.count, 1)
    }

    func testBeginningNewConversationKeepsRecentChats() async throws {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "领导说：你再想想。"
        _ = await store.runAnalysis()
        let previousExchange = try XCTUnwrap(store.exchanges.first)

        store.beginNewConversation()

        XCTAssertEqual(store.exchanges.map(\.id), [previousExchange.id])
        XCTAssertNil(store.selectedExchangeID)
        XCTAssertNil(store.result)
        XCTAssertTrue(store.draft.conversationText.isEmpty)
    }

    func testCancelAnalysisRestoresSubmittedDraft() async {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "领导说：你再想想。"

        let task = Task { await store.runAnalysis() }
        await Task.yield()
        store.cancelAnalysis()
        let completed = await task.value

        XCTAssertFalse(completed)
        XCTAssertFalse(store.isAnalyzing)
        XCTAssertTrue(store.exchanges.isEmpty)
        XCTAssertEqual(store.draft.conversationText, "领导说：你再想想。")
    }

    func testUserProfileAndPointsCanBeUpdated() {
        let store = AppStore(persistsChanges: false)

        XCTAssertEqual(store.userProfile.displayName, "灵嗅用户")
        XCTAssertEqual(store.userProfile.points, 200)

        store.updateUserProfile(displayName: " 阿龙 ", avatarData: nil)
        store.addPoints(120)

        XCTAssertEqual(store.userProfile.displayName, "阿龙")
        XCTAssertEqual(store.userProfile.points, 320)
        XCTAssertEqual(store.pointTransactions.count, 1)
        XCTAssertEqual(store.pointTransactions.first?.amount, 120)
        XCTAssertEqual(store.pointTransactions.first?.title, "购买积分")
    }

    func testConsumingPointsCreatesUsageTransactionAndPreventsNegativeBalance() {
        let store = AppStore(persistsChanges: false)

        XCTAssertTrue(store.consumePoints(3, title: "沟通分析", detail: "文字分析"))
        XCTAssertEqual(store.userProfile.points, 197)
        XCTAssertEqual(store.pointTransactions.first?.amount, -3)
        XCTAssertEqual(store.pointTransactions.first?.detail, "文字分析")

        XCTAssertFalse(store.consumePoints(10_000))
        XCTAssertEqual(store.userProfile.points, 197)
        XCTAssertEqual(store.pointTransactions.count, 1)
    }

    func testCompletedAnalysisRecordsOnePointUsage() async {
        let store = AppStore(persistsChanges: false)
        store.draft.conversationText = "领导说：这个方案再想想。"

        let submitted = await store.runAnalysis()
        XCTAssertTrue(submitted)
        XCTAssertEqual(store.userProfile.points, 199)
        XCTAssertEqual(store.pointTransactions.count, 1)
        XCTAssertEqual(store.pointTransactions.first?.amount, -1)
        XCTAssertEqual(store.pointTransactions.first?.title, "沟通分析")
    }

    func testAnalysisWithNoPointsKeepsDraftAndPublishesPurchasePrompt() async {
        let store = AppStore(persistsChanges: false)
        store.userProfile = UserProfile(points: 0)
        store.draft.conversationText = "请帮我判断这句话该怎么回复。"

        let submitted = await store.runAnalysis()

        XCTAssertFalse(submitted)
        XCTAssertEqual(store.draft.conversationText, "请帮我判断这句话该怎么回复。")
        XCTAssertEqual(store.pointErrorMessage, "当前积分已用完，请先购买积分后再进行沟通分析。")
        XCTAssertTrue(store.pointTransactions.isEmpty)
    }

    func testPointTransactionsPersistAndReload() {
        let suiteName = "LingXiuPointHistoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let firstStore = AppStore(defaults: defaults)
        firstStore.addPoints(120, detail: "120 积分包")
        XCTAssertEqual(firstStore.pointTransactions.count, 1)

        let secondStore = AppStore(defaults: defaults)
        XCTAssertEqual(secondStore.pointTransactions, firstStore.pointTransactions)
        XCTAssertEqual(secondStore.userProfile.points, firstStore.userProfile.points)
    }
}
