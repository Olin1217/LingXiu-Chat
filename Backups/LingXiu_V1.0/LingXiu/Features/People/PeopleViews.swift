import SwiftUI

struct PeopleListView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    @State private var showNewPerson = false

    private let categories = ["全部", "职场", "客户", "家庭", "朋友", "情感", "其他"]

    private var filteredPeople: [PersonProfile] {
        store.people.filter { person in
            let matchesCategory = selectedCategory == "全部" || person.category == selectedCategory
            let matchesSearch = searchText.isEmpty || person.name.localizedCaseInsensitiveContains(searchText) || person.relation.localizedCaseInsensitiveContains(searchText)
            return matchesCategory && matchesSearch
        }
    }

    var body: some View {
        List {
            Section {
                Picker("分类", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if filteredPeople.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "还没有人物" : "没有匹配人物", systemImage: "person.2.slash")
                } description: {
                    Text("创建人物角色卡，让后续建议更贴近实际互动。")
                } actions: {
                    Button("新建人物") { showNewPerson = true }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                Section("\(filteredPeople.count) 个人物") {
                    ForEach(filteredPeople) { person in
                        NavigationLink {
                            PersonDetailView(personID: person.id)
                        } label: {
                            PersonRow(person: person)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("删除", role: .destructive) {
                                store.people.removeAll { $0.id == person.id }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("人物")
        .searchable(text: $searchText, prompt: "搜索姓名或关系")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewPerson = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("新建人物")
            }
        }
        .sheet(isPresented: $showNewPerson) {
            PersonFormView(mode: .create) { person in
                store.addPerson(person)
            }
        }
    }
}

private struct PersonRow: View {
    let person: PersonProfile

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(symbol: person.avatarSymbol, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(person.name)
                        .font(.headline)
                    TagLabel(text: person.relation)
                }
                Text(person.traits.prefix(2).joined(separator: "、"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("最近互动：\(person.lastInteraction.formatted(.relative(presentation: .named))) · \(person.relationshipStage)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

enum PersonFormMode {
    case create
    case edit(PersonProfile)

    var title: String {
        switch self {
        case .create: "新建人物"
        case .edit: "编辑人物"
        }
    }
}

struct PersonFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var relation: String
    @State private var category: String
    @State private var identity: String
    @State private var avatarSymbol: String
    @State private var relationshipStage: String
    @State private var knownDuration: String
    @State private var traits: Set<String>
    @State private var notes: String

    let mode: PersonFormMode
    let onSave: (PersonProfile) -> Void

    private let traitOptions = ["喜欢简洁", "重视结果", "关注细节", "习惯委婉表达", "表达直接", "情绪敏感", "回复较慢", "习惯使用表情", "不喜欢被催", "重视礼节"]

    init(mode: PersonFormMode, onSave: @escaping (PersonProfile) -> Void) {
        self.mode = mode
        self.onSave = onSave
        let person: PersonProfile?
        if case let .edit(existing) = mode { person = existing } else { person = nil }
        _name = State(initialValue: person?.name ?? "")
        _relation = State(initialValue: person?.relation ?? "同事")
        _category = State(initialValue: person?.category ?? "职场")
        _identity = State(initialValue: person?.identity ?? "")
        _avatarSymbol = State(initialValue: person?.avatarSymbol ?? "person.crop.circle.fill")
        _relationshipStage = State(initialValue: person?.relationshipStage ?? "日常合作")
        _knownDuration = State(initialValue: person?.knownDuration ?? "")
        _traits = State(initialValue: Set(person?.traits ?? []))
        _notes = State(initialValue: person?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基础信息") {
                    HStack {
                        Spacer()
                        AvatarView(symbol: avatarSymbol, size: 72)
                        Spacer()
                    }
                    Picker("头像图标", selection: $avatarSymbol) {
                        Label("人物", systemImage: "person.crop.circle.fill").tag("person.crop.circle.fill")
                        Label("职场", systemImage: "briefcase.circle.fill").tag("briefcase.circle.fill")
                        Label("客户", systemImage: "building.2.crop.circle.fill").tag("building.2.crop.circle.fill")
                        Label("家人", systemImage: "heart.circle.fill").tag("heart.circle.fill")
                        Label("朋友", systemImage: "person.2.circle.fill").tag("person.2.circle.fill")
                    }
                    TextField("备注名称", text: $name)
                    TextField("职业或身份（可选）", text: $identity)
                }

                Section("与我的关系") {
                    Picker("关系", selection: $relation) {
                        ForEach(["老板", "直属领导", "上级", "同事", "下属", "客户", "合作方", "供应商", "亲人", "恋人", "朋友", "其他"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    Picker("分类", selection: $category) {
                        ForEach(["职场", "客户", "家庭", "朋友", "情感", "其他"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }

                Section("关系背景") {
                    TextField("认识时长，例如：1 年", text: $knownDuration)
                    Picker("当前关系阶段", selection: $relationshipStage) {
                        ForEach(["初次接触", "正在建立信任", "日常合作", "关系稳定", "有轻微矛盾", "冲突中", "长期疏远"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }

                Section("已知沟通特点") {
                    ForEach(traitOptions, id: \.self) { trait in
                        Toggle(trait, isOn: Binding(
                            get: { traits.contains(trait) },
                            set: { selected in
                                if selected { traits.insert(trait) }
                                else { traits.remove(trait) }
                            }
                        ))
                    }
                }

                Section("用户补充") {
                    TextField("例如：不喜欢长篇解释，更关心完成时间。", text: $notes, axis: .vertical)
                        .lineLimit(3...7)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("取消")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("保存")
                }
            }
        }
    }

    private func save() {
        let existing: PersonProfile?
        if case let .edit(person) = mode { existing = person } else { existing = nil }
        let person = PersonProfile(
            id: existing?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            relation: relation,
            category: category,
            identity: identity,
            avatarSymbol: avatarSymbol,
            relationshipStage: relationshipStage,
            knownDuration: knownDuration,
            traits: traits.sorted(),
            preferences: existing?.preferences ?? [],
            risks: existing?.risks ?? [],
            strategies: existing?.strategies ?? [],
            notes: notes,
            lastInteraction: existing?.lastInteraction ?? .now
        )
        onSave(person)
        dismiss()
    }
}

struct PersonDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var showEdit = false
    let personID: UUID

    private var person: PersonProfile? {
        store.people.first { $0.id == personID }
    }

    private var history: [AnalysisRecord] {
        store.records.filter { $0.personID == personID }
    }

    var body: some View {
        Group {
            if let person {
                List {
                    header(person)
                    portrait(person)
                    textListSection("沟通偏好", items: person.preferences, symbol: "checkmark.circle.fill")
                    commonExpressions
                    textListSection("关系雷区", items: person.risks, symbol: "exclamationmark.triangle.fill")
                    textListSection("推荐策略", items: person.strategies, symbol: "lightbulb.fill")
                    historySection
                }
                .navigationTitle(person.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") { showEdit = true }
                    }
                }
                .sheet(isPresented: $showEdit) {
                    PersonFormView(mode: .edit(person)) { updated in
                        guard let index = store.people.firstIndex(where: { $0.id == updated.id }) else { return }
                        store.people[index] = updated
                    }
                }
            } else {
                ContentUnavailableView("人物不存在", systemImage: "person.crop.circle.badge.questionmark")
            }
        }
    }

    private func header(_ person: PersonProfile) -> some View {
        Section {
            VStack(spacing: 14) {
                AvatarView(symbol: person.avatarSymbol, size: 82)
                VStack(spacing: 5) {
                    Text(person.name).font(.title2).fontWeight(.bold)
                    Text("\(person.relation) · \(person.identity)")
                        .foregroundStyle(.secondary)
                    FlowLayout {
                        TagLabel(text: person.relationshipStage, color: .accentColor)
                        if !person.knownDuration.isEmpty { TagLabel(text: "认识 \(person.knownDuration)") }
                    }
                }
                Button {
                    store.startAnalysis(for: person)
                } label: {
                    Label("基于这个人开始分析", systemImage: "sparkles")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }

    private func portrait(_ person: PersonProfile) -> some View {
        Section("沟通画像") {
            FlowLayout {
                ForEach(person.traits, id: \.self) { TagLabel(text: $0, color: .accentColor) }
            }
            LabeledContent("表达直接度", value: person.traits.contains("表达直接") ? "较高" : "中等")
            LabeledContent("结果导向程度", value: person.traits.contains("重视结果") || person.traits.contains("结果导向") ? "较高" : "中等")
            LabeledContent("礼节重视度", value: person.traits.contains("重视礼节") ? "较高" : "中等")
            LabeledContent("信任程度", value: person.relationshipStage == "关系稳定" || person.relationshipStage == "稳定合作" ? "稳定" : "建立中")
            Text("文字等级来自已知信息和历史互动，不是心理评分。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func textListSection(_ title: String, items: [String], symbol: String) -> some View {
        Section(title) {
            if items.isEmpty {
                Text("还没有足够信息")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items, id: \.self) { item in
                    Label(item, systemImage: symbol)
                }
            }
        }
    }

    private var commonExpressions: some View {
        Section("常见表达") {
            DisclosureGroup("“你再看看”") {
                Text("可能是希望继续改进，也可能是在观察主动判断。需要结合当时任务和后续反馈。")
                    .foregroundStyle(.secondary)
            }
            DisclosureGroup("“后面再说”") {
                Text("可能是暂缓决策、当时忙碌或优先级降低，不应直接等同于拒绝。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var historySection: some View {
        Section("历史互动") {
            if history.isEmpty {
                Text("还没有关联的分析记录")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(history) { record in
                    NavigationLink {
                        RecordDetailView(recordID: record.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.originalText).lineLimit(1)
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
