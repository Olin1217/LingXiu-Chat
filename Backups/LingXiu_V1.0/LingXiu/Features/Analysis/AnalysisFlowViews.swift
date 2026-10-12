import SwiftUI
import UIKit

struct ContextSupplementView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Text("信息越完整，分析会越贴近真实情况。也可以直接跳过。")
                    .foregroundStyle(.secondary)
            }

            Section("这是谁？") {
                Picker("关联人物", selection: Binding(
                    get: { store.draft.associatedPersonID },
                    set: { store.draft.associatedPersonID = $0 }
                )) {
                    Text("暂不关联").tag(UUID?.none)
                    ForEach(store.people) { person in
                        Text("\(person.name) · \(person.relation)").tag(UUID?.some(person.id))
                    }
                }
            }

            Section("双方身份") {
                TextField("我的身份，例如：员工", text: Binding(
                    get: { store.draft.userRole },
                    set: { store.draft.userRole = $0 }
                ))
                TextField("对方身份，例如：直属领导", text: Binding(
                    get: { store.draft.otherRole },
                    set: { store.draft.otherRole = $0 }
                ))
            }

            Section("权力关系") {
                Picker("权力关系", selection: Binding(
                    get: { store.draft.powerRelation },
                    set: { store.draft.powerRelation = $0 }
                )) {
                    ForEach(["对方明显更强势", "双方相对平等", "我更有决策权", "不确定"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }

            Section("当前关系状态") {
                Picker("关系状态", selection: Binding(
                    get: { store.draft.relationshipStage },
                    set: { store.draft.relationshipStage = $0 }
                )) {
                    ForEach(["初次接触", "正在建立信任", "日常合作", "关系稳定", "有轻微矛盾", "冲突中", "长期疏远", "不确定"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }

            Section("时间与回复节奏") {
                Picker("沟通时间", selection: Binding(
                    get: { store.draft.responseTiming },
                    set: { store.draft.responseTiming = $0 }
                )) {
                    ForEach(["刚刚", "今天", "昨天", "更早"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }

            Section("场景信息") {
                ForEach(["工作日", "下班后", "深夜", "节假日", "对方忙碌时", "公开群聊", "私密沟通", "有第三方在场"], id: \.self) { item in
                    Toggle(item, isOn: Binding(
                        get: { store.draft.sceneDetails.contains(item) },
                        set: { selected in
                            if selected { store.draft.sceneDetails.insert(item) }
                            else { store.draft.sceneDetails.remove(item) }
                        }
                    ))
                }
            }
        }
        .navigationTitle("再补充一点背景")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Button {
                    store.analysisPath.append(.analyzing)
                } label: {
                    Text("开始分析")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .primaryActionStyle()
                .disabled(store.remainingAnalyses == 0)

                Button("跳过并分析") {
                    store.analysisPath.append(.analyzing)
                }
                .font(.subheadline)
                .disabled(store.remainingAnalyses == 0)

                if store.remainingAnalyses == 0 {
                    Text("今日免费分析次数已用完，可在“我的”查看会员方案。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .background(.bar)
        }
    }
}

struct AnalysisProgressView: View {
    @Environment(AppStore.self) private var store
    @State private var completedSteps = 0
    @State private var didStart = false

    private let steps = [
        "识别聊天内容",
        "判断人物关系",
        "分析语气与表达",
        "推测可能意图",
        "评估沟通风险",
        "准备回应策略"
    ]

    private let messages = [
        "正在结合双方身份判断表达分寸",
        "正在检查标点和上下文变化",
        "正在区分客套、暗示、拒绝和真实需求",
        "正在生成不同目标下的回应方案"
    ]

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            ProgressView(value: Double(completedSteps), total: Double(steps.count)) {
                Text("正在分析这次沟通")
                    .font(.title2)
                    .fontWeight(.bold)
            } currentValueLabel: {
                Text("\(completedSteps) / \(steps.count)")
                    .font(.caption.monospacedDigit())
            }
            .progressViewStyle(.linear)
            .padding(.horizontal, 32)

            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        Image(systemName: index < completedSteps ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index < completedSteps ? Color.accentColor : Color.secondary)
                        Text(step)
                            .foregroundStyle(index < completedSteps ? .primary : .secondary)
                        Spacer()
                    }
                }
            }
            .padding()
            .appCard()
            .padding(.horizontal)

            Text(messages[min(completedSteps / 2, messages.count - 1)])
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("正在分析")
        .navigationBarBackButtonHidden()
        .task {
            guard !didStart else { return }
            didStart = true

            for index in 1...steps.count {
                try? await Task.sleep(for: .milliseconds(260))
                withAnimation(.smooth) { completedSteps = index }
            }
            await store.runAnalysis()
            store.analysisPath.append(.result)
        }
    }
}

struct AnalysisResultView: View {
    @Environment(AppStore.self) private var store
    @State private var showSaved = false
    @State private var inaccurateSignalIDs: Set<UUID> = []

    var body: some View {
        Group {
            if let result = store.result {
                List {
                    overviewSection(result)
                    meaningSection(result)
                    signalsSection(result)
                    profileSection(result)
                    expectationSection(result)
                    relationshipSection(result)
                    riskSection(result)
                    actionsSection(result)

                    Section {
                        SafetyDisclaimer()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.insetGrouped)
                .safeAreaInset(edge: .bottom) {
                    Button {
                        store.analysisPath.append(.goals)
                    } label: {
                        Text("选择回应方式")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .primaryActionStyle()
                    .padding()
                    .background(.bar)
                }
            } else {
                ContentUnavailableView("暂时没有分析结果", systemImage: "exclamationmark.magnifyingglass", description: Text("请返回并重新开始分析。"))
            }
        }
        .navigationTitle("沟通分析")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("保存分析", systemImage: "bookmark") {
                        store.saveAnalysisOnly()
                        showSaved = true
                    }
                    Button("补充信息", systemImage: "plus.bubble") {
                        store.analysisPath.append(.supplement)
                    }
                    if let result = store.result {
                        ShareLink(item: shareText(result), preview: SharePreview("沟通分析")) {
                            Label("分享结果", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("重新分析", systemImage: "arrow.clockwise") {
                        store.analysisPath = [.newAnalysis(store.draft.inputMode, nil)]
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
        .alert("已保存", isPresented: $showSaved) {
            Button("好", role: .cancel) {}
        } message: {
            Text("本次分析已经加入记录。")
        }
    }

    private func overviewSection(_ result: AnalysisResult) -> some View {
        Section {
            HStack(spacing: 12) {
                AvatarView(symbol: store.associatedPerson?.avatarSymbol ?? "person.crop.circle.fill")
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.associatedPerson?.name ?? store.draft.relation)
                        .font(.headline)
                    HStack {
                        TagLabel(text: store.draft.relation)
                        if let scene = store.draft.occasions.first {
                            TagLabel(text: scene)
                        }
                    }
                }
            }

            Text(result.summary)
                .font(.title3)
                .fontWeight(.semibold)
                .padding(.vertical, 4)
            Text("以下内容为基于当前信息的可能性分析，不代表对方真实心理的确定结论。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func meaningSection(_ result: AnalysisResult) -> some View {
        Section("话外之意") {
            LabeledContent("表层意思") {
                Text(result.surfaceMeaning)
                    .multilineTextAlignment(.trailing)
            }
            ForEach(result.intentions) { intention in
                DisclosureGroup {
                    ForEach(intention.evidence, id: \.self) { evidence in
                        Label(evidence, systemImage: "checkmark.circle")
                            .font(.subheadline)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(intention.label)
                        LikelihoodBadge(likelihood: intention.likelihood)
                    }
                }
            }
            DisclosureGroup("其他可能") {
                ForEach(result.otherPossibilities, id: \.self) { item in
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func signalsSection(_ result: AnalysisResult) -> some View {
        Section("AI 注意到的信号") {
            ForEach(result.signals) { signal in
                DisclosureGroup {
                    Text(signal.evidence)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button(inaccurateSignalIDs.contains(signal.id) ? "已标记不准确" : "这项不准确", systemImage: inaccurateSignalIDs.contains(signal.id) ? "checkmark" : "hand.thumbsdown") {
                        if inaccurateSignalIDs.contains(signal.id) {
                            inaccurateSignalIDs.remove(signal.id)
                        } else {
                            inaccurateSignalIDs.insert(signal.id)
                        }
                    }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(signal.dimension).font(.headline)
                            Text(signal.finding)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: signal.symbol)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
    }

    private func profileSection(_ result: AnalysisResult) -> some View {
        Section("当前沟通特点") {
            FlowLayout {
                ForEach(result.traits, id: \.self) { trait in
                    TagLabel(text: trait, color: .accentColor)
                }
            }
            Text("这些是当前沟通中表现出的倾向，不是对人物的固定标签。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func expectationSection(_ result: AnalysisResult) -> some View {
        Section("对方可能期待") {
            ForEach(result.expectations) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.label).font(.headline)
                        Spacer()
                        LikelihoodBadge(likelihood: item.likelihood)
                    }
                    if let evidence = item.evidence.first {
                        Text(evidence)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func relationshipSection(_ result: AnalysisResult) -> some View {
        Section("当前关系状态") {
            LabeledContent("信任程度", value: result.relationship.trust)
            LabeledContent("沟通压力", value: result.relationship.pressure)
            LabeledContent("权力差", value: result.relationship.power)
            LabeledContent("当前阶段", value: result.relationship.stage)
            Label(result.relationship.advice, systemImage: "lightbulb.max.fill")
                .font(.subheadline)
        }
    }

    private func riskSection(_ result: AnalysisResult) -> some View {
        Section("需要注意") {
            ForEach(result.risks) { risk in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: risk.level == "高" ? "exclamationmark.triangle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(risk.level == "高" ? .red : .orange)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(risk.level)风险")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(risk.message)
                    }
                }
            }
        }
    }

    private func actionsSection(_ result: AnalysisResult) -> some View {
        Section("建议行动") {
            ForEach(Array(result.recommendedActions.enumerated()), id: \.offset) { index, item in
                Label(item, systemImage: "\(index + 1).circle.fill")
            }
        }
    }

    private func shareText(_ result: AnalysisResult) -> String {
        "沟通分析\n\n核心结论：\(result.summary)\n\n建议：\(result.recommendedActions.joined(separator: "；"))\n\n以上为基于当前信息的可能性分析。"
    }
}

struct ResponseGoalView: View {
    @Environment(AppStore.self) private var store

    private let goals = [
        "接受", "部分接受", "委婉拒绝", "明确拒绝", "解释原因", "争取时间",
        "请求更多信息", "提供替代方案", "表达不同意见", "保持关系", "保持距离", "结束话题"
    ]

    private let workplaceGoals = ["接受任务并确认时间", "表现主动性", "请求领导给方向", "保留专业判断", "说明资源不足", "争取优先级调整"]

    var body: some View {
        @Bindable var store = store

        List {
            Section {
                Text("先选择你想达到的结果，AI 会按你的立场生成回复。")
                    .foregroundStyle(.secondary)
            }
            goalSection("通用目标", goals)
            goalSection("职场目标", workplaceGoals)
            Section("自定义目标") {
                TextField("例如：不想接受，但不希望显得在推卸责任", text: $store.customGoal, axis: .vertical)
                    .lineLimit(3...6)
                    .onTapGesture { store.selectedGoal = "自定义目标" }
            }
        }
        .navigationTitle("你希望怎么回应？")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.analysisPath.append(.replyStyle)
            } label: {
                Text("设置回复风格")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .primaryActionStyle()
            .disabled(store.selectedGoal == "自定义目标" && store.customGoal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding()
            .background(.bar)
        }
    }

    private func goalSection(_ title: String, _ goals: [String]) -> some View {
        Section(title) {
            ForEach(goals, id: \.self) { goal in
                Button {
                    store.selectedGoal = goal
                    store.customGoal = ""
                } label: {
                    HStack {
                        Text(goal).foregroundStyle(.primary)
                        Spacer()
                        if store.selectedGoal == goal {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }
        }
    }
}

struct ReplyStyleView: View {
    @Environment(AppStore.self) private var store
    private let inclusions = ["下一步动作", "完成时间", "替代方案", "反问 / 确认问题", "感谢或认可", "情绪表达"]
    private let exclusions = ["不要道歉", "不要解释过多", "不要承诺具体时间", "不要过度热情", "不要使用表情", "不要使用敬语", "不要使用“收到”"]

    var body: some View {
        @Bindable var store = store

        Form {
            Section("语气") {
                Picker("语气", selection: $store.replySettings.tone) {
                    ForEach(ReplyTone.allCases) { tone in
                        Text(tone.rawValue).tag(tone)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section("回复长度") {
                Picker("长度", selection: $store.replySettings.length) {
                    ForEach(ReplyLength.allCases) { length in
                        Text(length.rawValue).tag(length)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("关系温度") {
                Slider(value: $store.replySettings.warmth, in: 0...1) {
                    Text("关系温度")
                } minimumValueLabel: {
                    Text("保持距离").font(.caption)
                } maximumValueLabel: {
                    Text("更亲近").font(.caption)
                }
            }

            Section("立场强度") {
                Slider(value: $store.replySettings.firmness, in: 0...1) {
                    Text("立场强度")
                } minimumValueLabel: {
                    Text("委婉").font(.caption)
                } maximumValueLabel: {
                    Text("坚定").font(.caption)
                }
            }

            Section("包含内容") {
                ForEach(inclusions, id: \.self) { item in
                    Toggle(item, isOn: setBinding(item, keyPath: \.inclusions))
                }
            }

            Section("禁止表达") {
                ForEach(exclusions, id: \.self) { item in
                    Toggle(item, isOn: setBinding(item, keyPath: \.exclusions))
                }
            }
        }
        .navigationTitle("设置回复风格")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.generateReplies()
                store.analysisPath.append(.replies)
            } label: {
                Text("生成回复")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .primaryActionStyle()
            .padding()
            .background(.bar)
        }
    }

    private func setBinding(_ item: String, keyPath: WritableKeyPath<ReplySettings, Set<String>>) -> Binding<Bool> {
        Binding(
            get: { store.replySettings[keyPath: keyPath].contains(item) },
            set: { selected in
                if selected { store.replySettings[keyPath: keyPath].insert(item) }
                else { store.replySettings[keyPath: keyPath].remove(item) }
            }
        )
    }
}

struct ReplyOptionsView: View {
    @Environment(AppStore.self) private var store
    @State private var copiedID: UUID?
    @State private var showCopied = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                summary
                ForEach(store.replies) { reply in
                    replyCard(reply)
                }
                strategyExplanation
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("推荐回复")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let first = store.replies.first {
                Button {
                    copy(first)
                } label: {
                    Text("复制推荐回复")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .primaryActionStyle()
                .padding()
                .background(.bar)
            }
        }
        .sensoryFeedback(.success, trigger: copiedID)
        .alert("已复制并保存", isPresented: $showCopied) {
            Button("好", role: .cancel) {}
        } message: {
            Text("回复已复制到剪贴板，本次分析也已加入记录。")
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.associatedPerson?.name ?? store.draft.relation)
                .font(.headline)
            FlowLayout {
                TagLabel(text: "目标：\(store.selectedGoal)", color: .accentColor)
                TagLabel(text: "语气：\(store.replySettings.tone.rawValue)")
                TagLabel(text: "立场：\(store.replySettings.firmness > 0.65 ? "坚定" : store.replySettings.firmness < 0.35 ? "委婉" : "平衡")")
            }
        }
        .padding()
        .appCard()
    }

    private func replyCard(_ reply: ReplyOption) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                TagLabel(text: reply.label, color: reply.label == "最稳妥" ? .green : .accentColor)
                Spacer()
                Button {
                    store.toggleFavoriteReply(id: reply.id)
                } label: {
                    Image(systemName: reply.isFavorite ? "star.fill" : "star")
                }
                .accessibilityLabel(reply.isFavorite ? "取消收藏" : "收藏")
            }
            Text(reply.text)
                .font(.body)
                .lineSpacing(3)
                .textSelection(.enabled)
            HStack {
                Button("复制", systemImage: "doc.on.doc") { copy(reply) }
                Spacer()
                Button("编辑", systemImage: "pencil") {
                    store.analysisPath.append(.editReply(reply.id))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(18)
        .appCard()
    }

    private var strategyExplanation: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("为什么这样回复？") {
                VStack(alignment: .leading, spacing: 8) {
                    Label("先认可对方关注点，降低对抗感", systemImage: "checkmark.circle")
                    Label("保留用户立场，避免完全被动接受", systemImage: "checkmark.circle")
                    Label("给出明确行动，增强执行感", systemImage: "checkmark.circle")
                    Label("提供时间点，减少继续追问", systemImage: "checkmark.circle")
                }
                .font(.subheadline)
                .padding(.top, 8)
            }
            Divider()
            Text("可能结果")
                .font(.headline)
            Text("有利于维持合作关系，也可能促使对方进一步明确要求。")
                .foregroundStyle(.secondary)
        }
        .padding()
        .appCard()
    }

    private func copy(_ reply: ReplyOption) {
        UIPasteboard.general.string = reply.text
        copiedID = reply.id
        store.saveRecord(using: reply)
        showCopied = true
    }
}

struct EditReplyView: View {
    @Environment(AppStore.self) private var store
    @State private var text = ""
    @State private var copied = false
    let replyID: UUID

    private var risks: [String] {
        LocalAnalysisEngine.riskMessages(for: text)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TextEditor(text: $text)
                    .frame(minHeight: 220)
                    .padding(10)
                    .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if risks.isEmpty {
                    Label("当前没有发现明显表达风险", systemImage: "checkmark.shield.fill")
                        .foregroundStyle(.green)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .appCard()
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("实时风险提示", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.orange)
                        ForEach(risks, id: \.self) { risk in
                            Text("• \(risk)")
                        }
                    }
                    .padding()
                    .appCard()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("一键优化")
                        .font(.headline)
                    FlowLayout {
                        Button("更简短") { shorten() }
                        Button("更礼貌") { makePolite() }
                        Button("更坚定") { makeFirm() }
                        Button("增加行动") { addAction() }
                        Button("去掉客套") { removePleasantries() }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .appCard()
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("编辑回复")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    store.updateReply(id: replyID, text: text)
                    UIPasteboard.general.string = text
                    copied = true
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .accessibilityLabel("复制")

                Button {
                    store.updateReply(id: replyID, text: text)
                } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("保存")
            }
        }
        .onAppear {
            text = store.replies.first(where: { $0.id == replyID })?.text ?? ""
        }
        .alert("已复制", isPresented: $copied) {
            Button("好", role: .cancel) {}
        }
    }

    private func shorten() {
        let firstSentence = text.split(separator: "。", maxSplits: 1).first.map(String.init) ?? text
        text = firstSentence.hasSuffix("。") ? firstSentence : firstSentence + "。"
    }

    private func makePolite() {
        if !text.hasPrefix("谢谢") { text = "谢谢您的反馈。" + text }
    }

    private func makeFirm() {
        text = text.replacingOccurrences(of: "我会尽量", with: "我会")
        text = text.replacingOccurrences(of: "应该可以", with: "可以")
    }

    private func addAction() {
        if !text.contains("同步") { text += "我会整理好下一步并及时同步您确认。" }
    }

    private func removePleasantries() {
        text = text.replacingOccurrences(of: "谢谢您的反馈。", with: "")
            .replacingOccurrences(of: "收到，", with: "")
    }
}
