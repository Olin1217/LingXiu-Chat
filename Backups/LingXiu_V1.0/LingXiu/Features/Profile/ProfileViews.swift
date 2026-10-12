import AuthenticationServices
import SwiftUI

struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("displayName") private var displayName = "沟通体验官"

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AccountView()
                } label: {
                    HStack(spacing: 14) {
                        AvatarView(symbol: "person.crop.circle.fill", size: 62)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isSignedIn ? displayName : "游客体验")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(isSignedIn ? "免费会员" : "登录后可在多设备恢复数据")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section {
                NavigationLink {
                    MembershipView()
                } label: {
                    Label("会员中心", systemImage: "crown.fill")
                        .badge("免费版")
                }
                LabeledContent("今日剩余分析", value: "\(store.remainingAnalyses) 次")
            }

            Section("偏好") {
                NavigationLink {
                    ReplyPreferencesView()
                } label: {
                    Label("我的回复风格", systemImage: "slider.horizontal.3")
                }
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("通知设置", systemImage: "bell.badge.fill")
                }
            }

            Section("隐私与支持") {
                NavigationLink {
                    PrivacyDataView()
                } label: {
                    Label("隐私与数据", systemImage: "hand.raised.fill")
                }
                NavigationLink {
                    HelpCenterView()
                } label: {
                    Label("帮助中心", systemImage: "questionmark.circle.fill")
                }
                NavigationLink {
                    FeedbackView()
                } label: {
                    Label("意见反馈", systemImage: "envelope.fill")
                }
                NavigationLink {
                    AboutView()
                } label: {
                    Label("关于我们", systemImage: "info.circle.fill")
                }
            }
        }
        .navigationTitle("我的")
    }
}

private struct AccountView: View {
    @AppStorage("isSignedIn") private var isSignedIn = false
    @AppStorage("displayName") private var displayName = "沟通体验官"
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        AvatarView(symbol: "person.crop.circle.fill", size: 86)
                        Text(isSignedIn ? displayName : "游客体验")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Spacer()
                }
                .padding(.vertical)
            }

            if isSignedIn {
                Section("账户") {
                    TextField("昵称", text: $displayName)
                    Button("退出登录", role: .destructive) {
                        isSignedIn = false
                    }
                }
            } else {
                Section {
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        switch result {
                        case let .success(authorization):
                            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                                let name = PersonNameComponentsFormatter().string(from: credential.fullName ?? PersonNameComponents())
                                if !name.isEmpty { displayName = name }
                                isSignedIn = true
                            }
                        case let .failure(error):
                            errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    Text("也可以继续以游客身份使用。游客数据只保存在当前设备。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("账户")
        .navigationBarTitleDisplayMode(.inline)
        .alert("登录未完成", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "请稍后再试。")
        }
    }
}

private struct MembershipView: View {
    @State private var showUnavailable = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Label("沟通顾问 Pro", systemImage: "crown.fill")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.tint)
                    Text("更多深度分析、长期人物记忆、高级模板和无痕分析。")
                        .foregroundStyle(.secondary)
                    Button("开始 7 天试用") {
                        showUnavailable = true
                    }
                        .buttonStyle(.borderedProminent)
                    Text("演示版本暂未接入 App Store 商品。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical)
            }

            Section("免费版") {
                Label("每日 3 次基础分析", systemImage: "checkmark.circle.fill")
                Label("最多创建 3 张人物角色卡", systemImage: "checkmark.circle.fill")
                Label("保存最近 30 条记录", systemImage: "checkmark.circle.fill")
            }

            Section("会员版") {
                Label("更多或不限次数分析", systemImage: "sparkles")
                Label("长期人物记忆与关系趋势", systemImage: "point.3.filled.connected.trianglepath.dotted")
                Label("高级模板与导出记录", systemImage: "square.and.arrow.up")
                Label("无痕分析", systemImage: "eye.slash.fill")
            }
        }
        .navigationTitle("会员中心")
        .navigationBarTitleDisplayMode(.inline)
        .alert("暂未开放购买", isPresented: $showUnavailable) {
            Button("好", role: .cancel) {}
        } message: {
            Text("演示版本尚未配置 App Store 商品，正式接入后会在这里显示价格与试用条款。")
        }
    }
}

private struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var category = "功能建议"
    @State private var message = ""
    @State private var submitted = false

    var body: some View {
        Form {
            Section("反馈类型") {
                Picker("类型", selection: $category) {
                    ForEach(["功能建议", "分析不准确", "交互问题", "隐私问题", "其他"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }
            Section("详细说明") {
                TextField("请描述你遇到的问题或建议", text: $message, axis: .vertical)
                    .lineLimit(5...10)
            }
            Section {
                Text("当前演示版本会在本机确认提交，不会向外部服务器发送。接入正式反馈服务后需要再次明确数据用途。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("意见反馈")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("提交") { submitted = true }
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .alert("感谢反馈", isPresented: $submitted) {
            Button("完成") { dismiss() }
        } message: {
            Text("你的反馈已在当前演示会话中确认。")
        }
    }
}

private struct ReplyPreferencesView: View {
    @AppStorage("preferHonorific") private var preferHonorific = true
    @AppStorage("preferEmoji") private var preferEmoji = false
    @AppStorage("preferActionPlan") private var preferActionPlan = true
    @AppStorage("avoidApology") private var avoidApology = false
    @AppStorage("defaultReplyLength") private var defaultReplyLength = ReplyLength.standard.rawValue
    @AppStorage("defaultTone") private var defaultTone = ReplyTone.professional.rawValue
    @AppStorage("commonEnding") private var commonEnding = ""
    @AppStorage("blockedWords") private var blockedWords = ""

    var body: some View {
        Form {
            Section("默认语气") {
                Picker("语气", selection: $defaultTone) {
                    ForEach(ReplyTone.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("平均长度", selection: $defaultReplyLength) {
                    ForEach(ReplyLength.allCases) { Text($0.rawValue).tag($0.rawValue) }
                }
            }
            Section("表达习惯") {
                Toggle("使用“您”", isOn: $preferHonorific)
                Toggle("使用表情", isOn: $preferEmoji)
                Toggle("强调行动计划", isOn: $preferActionPlan)
                Toggle("默认避免道歉", isOn: $avoidApology)
            }
            Section("常用表达") {
                TextField("常用结尾", text: $commonEnding)
                TextField("禁用词，用逗号分隔", text: $blockedWords, axis: .vertical)
                    .lineLimit(2...5)
            }
        }
        .navigationTitle("我的回复风格")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyDataView: View {
    @Environment(AppStore.self) private var store
    @AppStorage("autoHideSensitiveInfo") private var autoHideSensitiveInfo = true
    @AppStorage("allowModelTraining") private var allowModelTraining = false
    @AppStorage("saveFeedback") private var saveFeedback = true
    @AppStorage("incognitoAnalysis") private var incognitoAnalysis = false
    @AppStorage("retentionPeriod") private var retentionPeriod = "长期（手动删除）"
    @State private var showClearConfirmation = false

    private var exportText: String {
        let peopleText = store.people.map { "人物：\($0.name)（\($0.relation)）" }.joined(separator: "\n")
        let recordText = store.records.map { "记录：\($0.originalText)\n回复：\($0.selectedReply)" }.joined(separator: "\n\n")
        return "灵嗅数据导出\n\n\(peopleText)\n\n\(recordText)"
    }

    var body: some View {
        Form {
            Section("分析隐私") {
                Toggle("自动隐藏头像和昵称", isOn: $autoHideSensitiveInfo)
                Toggle("无痕分析", isOn: $incognitoAnalysis)
                Toggle("保存结果反馈", isOn: $saveFeedback)
                Toggle("允许用于模型优化", isOn: $allowModelTraining)
                Text("默认关闭模型优化。截图 OCR 在设备本地完成。接入真实 AI 服务后，还需要在服务端落实加密、删除和保存期限策略。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("数据保存") {
                Picker("保存期限", selection: $retentionPeriod) {
                    Text("7 天").tag("7 天")
                    Text("30 天").tag("30 天")
                    Text("长期（手动删除）").tag("长期（手动删除）")
                }
                ShareLink(item: exportText) {
                    Label("导出我的数据", systemImage: "square.and.arrow.up")
                }
                LabeledContent("人物角色卡", value: "\(store.people.count) 张")
                LabeledContent("分析记录", value: "\(store.records.count) 条")
            }

            Section {
                Button("清空全部数据", role: .destructive) {
                    showClearConfirmation = true
                }
            } footer: {
                Text("此操作会删除本机的人物和分析记录，且无法恢复。")
            }
        }
        .navigationTitle("隐私与数据")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("确认清空全部数据？", isPresented: $showClearConfirmation, titleVisibility: .visible) {
            Button("清空全部数据", role: .destructive) {
                store.clearAllUserData()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("人物角色卡和分析记录将从当前设备删除，无法恢复。")
        }
    }
}

private struct NotificationSettingsView: View {
    @AppStorage("feedbackReminder") private var feedbackReminder = true
    @AppStorage("usageReminder") private var usageReminder = false
    @AppStorage("productUpdates") private var productUpdates = false

    var body: some View {
        Form {
            Section {
                Toggle("结果反馈提醒", isOn: $feedbackReminder)
                Toggle("免费次数恢复提醒", isOn: $usageReminder)
                Toggle("产品更新", isOn: $productUpdates)
            } footer: {
                Text("系统通知权限需要在首次发送前由你确认，也可以随时在系统设置中关闭。")
            }
        }
        .navigationTitle("通知设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HelpCenterView: View {
    var body: some View {
        List {
            Section("常见问题") {
                DisclosureGroup("分析结果代表对方真实想法吗？") {
                    Text("不代表。结果是根据现有文字、关系和场景做出的可能性分析，应结合现实证据判断。")
                }
                DisclosureGroup("截图会上传吗？") {
                    Text("当前演示版本的 OCR 在设备本地完成。未来接入云端 AI 时，会在发送前明确提示数据用途。")
                }
                DisclosureGroup("怎样提高分析质量？") {
                    Text("保留前后文，说明身份与权力关系，并描述你最担心的结果。")
                }
                DisclosureGroup("为什么不直接告诉我对方在想什么？") {
                    Text("沟通信息存在多种解释。产品会提供证据和可能性，而不是给出无法验证的心理定论。")
                }
            }
            Section {
                SafetyDisclaimer()
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("帮助中心")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 64, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                    Text("灵嗅")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("版本 1.0 MVP")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }
            Section("产品原则") {
                Label("概率表达，不做心理定论", systemImage: "chart.bar.doc.horizontal")
                Label("证据可见，用户掌握决策权", systemImage: "checkmark.shield")
                Label("隐私优先，不自动发送消息", systemImage: "hand.raised")
            }
            Section {
                Text("AI 帮你读懂话外之意，判断关系局势，并给出更合适的回应方式。")
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
