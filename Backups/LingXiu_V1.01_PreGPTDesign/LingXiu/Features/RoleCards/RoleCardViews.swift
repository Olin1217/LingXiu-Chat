import SwiftUI

struct RoleCardListView: View {
    @Environment(AppStore.self) private var store
    @State private var editorMode: RoleCardEditorMode?

    var body: some View {
        List {
            if store.roleCards.isEmpty {
                ContentUnavailableView {
                    Label("还没有聊天角色卡", systemImage: "person.text.rectangle")
                } description: {
                    Text("描述一个人以及你们的关系，AI 分析时就能参考这些背景。")
                } actions: {
                    Button("创建角色卡") {
                        editorMode = .create
                    }
                    .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("\(store.roleCards.count) 张角色卡") {
                    ForEach(store.roleCards) { card in
                        NavigationLink {
                            RoleCardDetailView(cardID: card.id)
                        } label: {
                            RoleCardRow(card: card)
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                store.deleteRoleCard(id: card.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("聊天角色卡")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editorMode = .create
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("创建角色卡")
            }
        }
        .sheet(item: $editorMode) { mode in
            RoleCardEditorView(mode: mode) { card in
                store.saveRoleCard(card)
            }
        }
    }
}

private struct RoleCardRow: View {
    let card: ChatRoleCard

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 36))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.name)
                        .font(.headline)
                    Text(card.relationship)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(rowSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var rowSummary: String {
        let values = [card.identity, card.mbti == "未填写" ? "" : card.mbti, card.speakingStyle, card.userDescription]
            .filter { !$0.isEmpty }
        return values.isEmpty ? "等待补充人物描述" : values.joined(separator: " · ")
    }
}

private struct RoleCardDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var editorMode: RoleCardEditorMode?
    let cardID: UUID

    private var card: ChatRoleCard? {
        store.roleCards.first { $0.id == cardID }
    }

    var body: some View {
        Group {
            if let card {
                List {
                    Section {
                        VStack(spacing: 10) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.system(size: 66))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(.tint)
                            Text(card.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text([card.relationship, card.identity].filter { !$0.isEmpty }.joined(separator: " · "))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)

                        Button {
                            store.startAnalysis(using: card)
                        } label: {
                            Label("用这个角色开始分析", systemImage: "sparkles")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity, minHeight: 42)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    Section("这个人是什么样的") {
                        Text(card.userDescription.isEmpty ? "还没有填写描述" : card.userDescription)
                            .foregroundStyle(card.userDescription.isEmpty ? .secondary : .primary)
                    }

                    Section("人物信息") {
                        LabeledContent("与我的关系", value: card.relationship)
                        if !card.identity.isEmpty { LabeledContent("身份", value: card.identity) }
                        if card.zodiacSign != "未填写" { LabeledContent("星座", value: card.zodiacSign) }
                        if !card.birthday.isEmpty { LabeledContent("生日", value: card.birthday) }
                        if !card.birthDetails.isEmpty { LabeledContent("生辰八字", value: card.birthDetails) }
                        if card.mbti != "未填写" { LabeledContent("MBTI", value: card.mbti) }
                        if !card.speakingStyle.isEmpty { LabeledContent("讲话风格", value: card.speakingStyle) }
                    }

                    if !card.notes.isEmpty {
                        Section("补充信息") {
                            Text(card.notes)
                        }
                    }

                    Section("AI 分析上下文") {
                        Text(card.contextSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("星座、MBTI 和生辰信息只作为用户提供的背景，不用于确定性判断人格或命运。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle(card.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") {
                            editorMode = .edit(card)
                        }
                    }
                }
                .sheet(item: $editorMode) { mode in
                    RoleCardEditorView(mode: mode) { updated in
                        store.saveRoleCard(updated)
                    }
                }
            } else {
                ContentUnavailableView("角色卡不存在", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
    }
}

private enum RoleCardEditorMode: Identifiable {
    case create
    case edit(ChatRoleCard)

    var id: String {
        switch self {
        case .create: "create"
        case let .edit(card): "edit-\(card.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create: "创建角色卡"
        case .edit: "编辑角色卡"
        }
    }

    var card: ChatRoleCard? {
        if case let .edit(card) = self { card } else { nil }
    }
}

private struct RoleCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var relationship: String
    @State private var identity: String
    @State private var userDescription: String
    @State private var zodiacSign: String
    @State private var birthday: String
    @State private var birthDetails: String
    @State private var mbti: String
    @State private var speakingStyle: String
    @State private var notes: String

    let mode: RoleCardEditorMode
    let onSave: (ChatRoleCard) -> Void

    private let relationships = ["领导", "老板", "上级", "同事", "下属", "客户", "合作伙伴", "朋友", "恋人", "家人", "长辈", "其他"]
    private let zodiacSigns = ["未填写", "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"]
    private let mbtiTypes = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

    init(mode: RoleCardEditorMode, onSave: @escaping (ChatRoleCard) -> Void) {
        self.mode = mode
        self.onSave = onSave
        let card = mode.card
        _name = State(initialValue: card?.name ?? "")
        _relationship = State(initialValue: card?.relationship ?? "朋友")
        _identity = State(initialValue: card?.identity ?? "")
        _userDescription = State(initialValue: card?.userDescription ?? "")
        _zodiacSign = State(initialValue: card?.zodiacSign ?? "未填写")
        _birthday = State(initialValue: card?.birthday ?? "")
        _birthDetails = State(initialValue: card?.birthDetails ?? "")
        _mbti = State(initialValue: card?.mbti ?? "未填写")
        _speakingStyle = State(initialValue: card?.speakingStyle ?? "")
        _notes = State(initialValue: card?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("称呼，例如：王总", text: $name)
                    Picker("与我的关系", selection: $relationship) {
                        ForEach(relationships, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("身份或职位（可选）", text: $identity)
                }

                Section("描述这个人") {
                    TextField("例如：说话直接、重视结果，不喜欢长篇解释；安排工作时通常只说结论。", text: $userDescription, axis: .vertical)
                        .lineLimit(4...8)
                    Text("请优先写你实际观察到的行为和讲话方式。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("参考资料（可选）") {
                    Picker("星座", selection: $zodiacSign) {
                        ForEach(zodiacSigns, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("生日，例如：1990 年 5 月 20 日", text: $birthday)
                    TextField("生辰八字或出生时间", text: $birthDetails)
                    Picker("MBTI", selection: $mbti) {
                        ForEach(mbtiTypes, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("沟通特点") {
                    TextField("讲话风格，例如：简洁直接、喜欢反问", text: $speakingStyle, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("其他补充", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Text("星座、MBTI 和生辰信息不会被当作确定性的人格或命运结论。实际沟通行为和上下文优先级更高。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let oldCard = mode.card
        let card = ChatRoleCard(
            id: oldCard?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            relationship: relationship,
            identity: identity.trimmingCharacters(in: .whitespacesAndNewlines),
            userDescription: userDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            zodiacSign: zodiacSign,
            birthday: birthday.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDetails: birthDetails.trimmingCharacters(in: .whitespacesAndNewlines),
            mbti: mbti,
            speakingStyle: speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            updatedAt: .now
        )
        onSave(card)
        dismiss()
    }
}
