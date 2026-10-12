import PhotosUI
import SwiftUI
import UIKit

struct RoleAvatarView: View {
    let card: ChatRoleCard?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let data = card?.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if card != nil {
                DefaultDogAvatarImage()
            } else {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: size * 0.52, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.subtleFill, in: Circle())
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct IdentityAvatarView: View {
    let card: IdentityCard?
    var size: CGFloat = 48

    var body: some View {
        Group {
            if let data = card?.avatarData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if card != nil {
                DefaultDogAvatarImage()
            } else {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: size * 0.52, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.subtleFill, in: Circle())
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

struct RoleCardListView: View {
    @Environment(AppStore.self) private var store
    @State private var editor: RoleCardListEditor?

    let onUse: ((ChatRoleCard) -> Void)?

    init(onUse: ((ChatRoleCard) -> Void)? = nil) {
        self.onUse = onUse
    }

    var body: some View {
        List {
            Section("沟通角色卡") {
                if store.roleCards.isEmpty {
                    Text("还没有沟通角色卡。创建后可以记录沟通对象与你的关系和讲话特点。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    ForEach(store.roleCards) { card in
                        NavigationLink {
                            RoleCardDetailView(cardID: card.id, onUse: onUse)
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

                Button {
                    editor = .role(.create)
                } label: {
                    Label("创建角色卡", systemImage: "plus")
                }
            }

            Section("我的身份卡") {
                if store.identityCards.isEmpty {
                    Text("还没有身份卡。创建后可以告诉灵嗅你在沟通中的身份和表达习惯。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                } else {
                    ForEach(store.identityCards) { card in
                        NavigationLink {
                            IdentityCardDetailView(cardID: card.id)
                        } label: {
                            IdentityCardRow(card: card)
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) {
                                store.deleteIdentityCard(id: card.id)
                            }
                        }
                    }
                }

                Button {
                    editor = .identity(.create)
                } label: {
                    Label("创建身份卡", systemImage: "plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("管理角色卡")
        .preservesBackgroundLayoutWhileKeyboardPresented(editor != nil)
        .sheet(item: $editor) { presentation in
            switch presentation {
            case let .role(mode):
                RoleCardEditorView(mode: mode) { card in
                    store.saveRoleCard(card)
                }
            case let .identity(mode):
                IdentityCardEditorView(mode: mode) { card in
                    store.saveIdentityCard(card)
                }
            }
        }
    }
}

private struct RoleCardRow: View {
    let card: ChatRoleCard

    var body: some View {
        HStack(spacing: 12) {
            RoleAvatarView(card: card, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.name)
                        .font(.headline)
                    Text(card.relationship)
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Text(rowSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
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

private struct IdentityCardRow: View {
    let card: IdentityCard

    var body: some View {
        HStack(spacing: 12) {
            IdentityAvatarView(card: card, size: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.headline)
                Text(rowSummary)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var rowSummary: String {
        let values = [card.identity, card.mbti == "未填写" ? "" : card.mbti, card.speakingStyle, card.userDescription]
            .filter { !$0.isEmpty }
        return values.isEmpty ? "等待补充身份描述" : values.joined(separator: " · ")
    }
}

private struct RoleCardDetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var editorMode: RoleCardEditorMode?

    let cardID: UUID
    let onUse: ((ChatRoleCard) -> Void)?

    private var card: ChatRoleCard? {
        store.roleCards.first { $0.id == cardID }
    }

    var body: some View {
        Group {
            if let card {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 12) {
                            RoleAvatarView(card: card, size: 104)
                            Text(card.name)
                                .font(.title2.weight(.bold))
                            Text([card.relationship, card.identity].filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)

                        ProfileDetailCard(title: "这个人是什么样的") {
                            Text(card.userDescription.isEmpty ? "还没有填写描述" : card.userDescription)
                                .font(.body)
                                .foregroundStyle(card.userDescription.isEmpty ? AppTheme.secondaryText : AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ProfileDetailCard(title: "角色卡信息") {
                            ProfileDetailRows(rows: roleInformation(for: card))
                        }

                        if !card.notes.isEmpty {
                            ProfileDetailTextSection(title: "自定义补充", text: card.notes)
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
                .background(AppTheme.pageBackground)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Button {
                        store.startAnalysis(using: card)
                        onUse?(card)
                        if onUse == nil { dismiss() }
                    } label: {
                        Label("进行对话", systemImage: "bubble.left.and.bubble.right.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 50)
                    }
                    .primaryActionStyle()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    .background(AppTheme.pageBackground)
                }
                .navigationTitle("角色卡信息")
                .navigationBarTitleDisplayMode(.inline)
                .preservesBackgroundLayoutWhileKeyboardPresented(editorMode != nil)
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
                ContentUnavailableView("角色卡不存在", systemImage: "person.badge.questionmark")
            }
        }
    }

    private func roleInformation(for card: ChatRoleCard) -> [(String, String)] {
        var rows = [("与我的关系", card.relationship)]
        if !card.identity.isEmpty { rows.append(("身份", card.identity)) }
        if card.zodiacSign != "未填写" { rows.append(("星座", card.zodiacSign)) }
        if !card.birthday.isEmpty { rows.append(("生日", card.birthday)) }
        if !card.birthDetails.isEmpty { rows.append(("生辰八字", card.birthDetails)) }
        if card.mbti != "未填写" { rows.append(("MBTI", card.mbti)) }
        if !card.speakingStyle.isEmpty { rows.append(("讲话风格", card.speakingStyle)) }
        return rows
    }
}

private struct IdentityCardDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var editorMode: IdentityCardEditorMode?

    let cardID: UUID

    private var card: IdentityCard? {
        store.identityCards.first { $0.id == cardID }
    }

    var body: some View {
        Group {
            if let card {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 12) {
                            IdentityAvatarView(card: card, size: 104)
                            Text(card.name)
                                .font(.title2.weight(.bold))
                            Text(card.identity.isEmpty ? "我的身份" : card.identity)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)

                        ProfileDetailCard(title: "我是什么样的") {
                            Text(card.userDescription.isEmpty ? "还没有填写自我描述" : card.userDescription)
                                .font(.body)
                                .foregroundStyle(card.userDescription.isEmpty ? AppTheme.secondaryText : AppTheme.primaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ProfileDetailCard(title: "身份卡信息") {
                            ProfileDetailRows(rows: identityInformation(for: card))
                        }

                        if !card.notes.isEmpty {
                            ProfileDetailTextSection(title: "自定义补充", text: card.notes)
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
                .background(AppTheme.pageBackground)
                .navigationTitle("身份卡信息")
                .navigationBarTitleDisplayMode(.inline)
                .preservesBackgroundLayoutWhileKeyboardPresented(editorMode != nil)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") {
                            editorMode = .edit(card)
                        }
                    }
                }
                .sheet(item: $editorMode) { mode in
                    IdentityCardEditorView(mode: mode) { updated in
                        store.saveIdentityCard(updated)
                    }
                }
            } else {
                ContentUnavailableView("身份卡不存在", systemImage: "person.badge.questionmark")
            }
        }
    }

    private func identityInformation(for card: IdentityCard) -> [(String, String)] {
        var rows: [(String, String)] = []
        if !card.identity.isEmpty { rows.append(("身份或职位", card.identity)) }
        if card.zodiacSign != "未填写" { rows.append(("星座", card.zodiacSign)) }
        if !card.birthday.isEmpty { rows.append(("生日", card.birthday)) }
        if !card.birthDetails.isEmpty { rows.append(("生辰八字", card.birthDetails)) }
        if card.mbti != "未填写" { rows.append(("MBTI", card.mbti)) }
        if !card.speakingStyle.isEmpty { rows.append(("讲话风格", card.speakingStyle)) }
        return rows.isEmpty ? [("资料", "还没有补充资料")] : rows
    }
}

private struct ProfileDetailCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

private struct ProfileDetailTextSection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.primaryText)
            Text(text)
                .font(.body)
                .foregroundStyle(AppTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 4)
    }
}

private struct ProfileDetailRows: View {
    let rows: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text(row.0)
                        .foregroundStyle(AppTheme.primaryText)
                    Spacer(minLength: 12)
                    Text(row.1)
                        .foregroundStyle(AppTheme.primaryText)
                        .multilineTextAlignment(.trailing)
                }
                .font(.body)
                .frame(minHeight: 48)

                if index < rows.count - 1 {
                    Divider()
                }
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
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?

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
        _avatarData = State(initialValue: card?.avatarData)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                EditableAvatarPicker(
                    data: avatarData,
                    item: $avatarItem,
                    accessibilityName: "角色头像"
                )
                .padding(.vertical, 12)

                Form {
                Section("基本信息") {
                    TextField("称呼，例如：王总", text: $name)
                        .onChange(of: name) { _, value in
                            let limited = String(value.prefix(ChatRoleCard.maximumNameLength))
                            if limited != value { name = limited }
                        }
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
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("参考资料（可选）") {
                    Picker("星座", selection: $zodiacSign) {
                        ForEach(zodiacSigns, id: \.self) { Text($0).tag($0) }
                    }
                    BirthdayPickerRow(value: $birthday)
                    TextField("生辰八字或出生时间", text: $birthDetails)
                    Picker("MBTI", selection: $mbti) {
                        ForEach(mbtiTypes, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("沟通特点") {
                    TextField("讲话风格，例如：简洁直接、喜欢反问", text: $speakingStyle, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("自定义补充", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(AppTheme.groupedBackground)
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
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .dismissesKeyboardOnBackgroundTap()
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
            avatarData: avatarData,
            updatedAt: .now
        )
        onSave(card)
        dismiss()
    }
}

private enum IdentityCardEditorMode: Identifiable {
    case create
    case edit(IdentityCard)

    var id: String {
        switch self {
        case .create: "create-identity"
        case let .edit(card): "edit-identity-\(card.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .create: "创建身份卡"
        case .edit: "编辑身份卡"
        }
    }

    var card: IdentityCard? {
        if case let .edit(card) = self { card } else { nil }
    }
}

private enum RoleCardListEditor: Identifiable {
    case role(RoleCardEditorMode)
    case identity(IdentityCardEditorMode)

    var id: String {
        switch self {
        case let .role(mode): "role-\(mode.id)"
        case let .identity(mode): "identity-\(mode.id)"
        }
    }
}

private struct IdentityCardEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var identity: String
    @State private var userDescription: String
    @State private var zodiacSign: String
    @State private var birthday: String
    @State private var birthDetails: String
    @State private var mbti: String
    @State private var speakingStyle: String
    @State private var notes: String
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?

    let mode: IdentityCardEditorMode
    let onSave: (IdentityCard) -> Void

    private let zodiacSigns = ["未填写", "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座", "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座"]
    private let mbtiTypes = ["未填写", "INTJ", "INTP", "ENTJ", "ENTP", "INFJ", "INFP", "ENFJ", "ENFP", "ISTJ", "ISFJ", "ESTJ", "ESFJ", "ISTP", "ISFP", "ESTP", "ESFP"]

    init(mode: IdentityCardEditorMode, onSave: @escaping (IdentityCard) -> Void) {
        self.mode = mode
        self.onSave = onSave
        let card = mode.card
        _name = State(initialValue: card?.name ?? "")
        _identity = State(initialValue: card?.identity ?? "")
        _userDescription = State(initialValue: card?.userDescription ?? "")
        _zodiacSign = State(initialValue: card?.zodiacSign ?? "未填写")
        _birthday = State(initialValue: card?.birthday ?? "")
        _birthDetails = State(initialValue: card?.birthDetails ?? "")
        _mbti = State(initialValue: card?.mbti ?? "未填写")
        _speakingStyle = State(initialValue: card?.speakingStyle ?? "")
        _notes = State(initialValue: card?.notes ?? "")
        _avatarData = State(initialValue: card?.avatarData)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                EditableAvatarPicker(
                    data: avatarData,
                    item: $avatarItem,
                    accessibilityName: "身份头像"
                )
                .padding(.vertical, 12)

                Form {
                Section("身份信息") {
                    TextField("身份名称，例如：工作中的我", text: $name)
                        .onChange(of: name) { _, value in
                            let limited = String(value.prefix(IdentityCard.maximumNameLength))
                            if limited != value { name = limited }
                        }
                    TextField("身份或职位，例如：产品经理", text: $identity)
                }

                Section("描述我自己") {
                    TextField("例如：职场新人，表达比较委婉，希望回复清晰但不显得强硬。", text: $userDescription, axis: .vertical)
                        .lineLimit(4...8)
                    Text("描述你在沟通中的位置、习惯和希望保持的表达方式。")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Section("参考资料（可选）") {
                    Picker("星座", selection: $zodiacSign) {
                        ForEach(zodiacSigns, id: \.self) { Text($0).tag($0) }
                    }
                    BirthdayPickerRow(value: $birthday)
                    TextField("生辰八字或出生时间", text: $birthDetails)
                    Picker("MBTI", selection: $mbti) {
                        ForEach(mbtiTypes, id: \.self) { Text($0).tag($0) }
                    }
                }

                Section("沟通特点") {
                    TextField("我的讲话风格，例如：温和、先解释背景", text: $speakingStyle, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("自定义补充", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(AppTheme.groupedBackground)
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
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .dismissesKeyboardOnBackgroundTap()
        }
    }

    private func save() {
        let oldCard = mode.card
        let card = IdentityCard(
            id: oldCard?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            identity: identity.trimmingCharacters(in: .whitespacesAndNewlines),
            userDescription: userDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            zodiacSign: zodiacSign,
            birthday: birthday.trimmingCharacters(in: .whitespacesAndNewlines),
            birthDetails: birthDetails.trimmingCharacters(in: .whitespacesAndNewlines),
            mbti: mbti,
            speakingStyle: speakingStyle.trimmingCharacters(in: .whitespacesAndNewlines),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            avatarData: avatarData,
            updatedAt: .now
        )
        onSave(card)
        dismiss()
    }
}

private struct EditableAvatarPicker: View {
    let data: Data?
    @Binding var item: PhotosPickerItem?
    let accessibilityName: String

    var body: some View {
        let cameraForeground = AppTheme.pureWhite
        let cameraBackground = AppTheme.accent
        let cameraBorder = AppTheme.pageBackground

        PhotosPicker(selection: $item, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                AvatarPreview(data: data)

                Image(systemName: "camera.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(cameraForeground)
                    .frame(width: 32, height: 32)
                    .background(cameraBackground, in: Circle())
                    .overlay {
                        Circle().stroke(cameraBorder, lineWidth: 3)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(data == nil ? "上传\(accessibilityName)" : "更换\(accessibilityName)")
        .accessibilityHint("从照片中选择")
    }
}

private struct BirthdayPickerRow: View {
    @Binding var value: String
    @State private var selectedDate: Date
    @State private var showPicker = false

    init(value: Binding<String>) {
        _value = value
        let fallback = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
        _selectedDate = State(initialValue: Self.date(from: value.wrappedValue) ?? fallback)
    }

    var body: some View {
        Button {
            if let parsedDate = Self.date(from: value) {
                selectedDate = parsedDate
            }
            showPicker = true
        } label: {
            LabeledContent("生日") {
                Text(value.isEmpty ? "选择日期" : value)
                    .foregroundStyle(value.isEmpty ? AppTheme.accent : AppTheme.primaryText)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPicker) {
            NavigationStack {
                DatePicker(
                    "生日",
                    selection: $selectedDate,
                    in: Self.earliestDate ... Date.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding()
                .navigationTitle("选择生日")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showPicker = false }
                    }
                    ToolbarItemGroup(placement: .confirmationAction) {
                        if !value.isEmpty {
                            Button("清除", role: .destructive) {
                                value = ""
                                showPicker = false
                            }
                        }
                        Button("完成") {
                            value = Self.string(from: selectedDate)
                            showPicker = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private static let earliestDate = Calendar.current.date(
        from: DateComponents(year: 1900, month: 1, day: 1)
    ) ?? .distantPast

    private static func date(from value: String) -> Date? {
        formatter.date(from: value.replacingOccurrences(of: " ", with: ""))
    }

    private static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日"
        return formatter
    }()
}

private struct AvatarPreview: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                DefaultDogAvatarImage()
            }
        }
        .frame(width: 92, height: 92)
        .background(AppTheme.subtleFill, in: Circle())
        .clipShape(Circle())
    }
}

private struct DefaultDogAvatarImage: View {
    var body: some View {
        Image("DefaultDogAvatar")
            .resizable()
            .scaledToFill()
            .accessibilityHidden(true)
    }
}
