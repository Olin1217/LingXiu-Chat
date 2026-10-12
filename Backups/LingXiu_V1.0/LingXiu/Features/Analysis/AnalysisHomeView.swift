import SwiftUI

struct AnalysisHomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showHelp = false

    private let sceneColumns = [GridItem(.adaptive(minimum: 145), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 24) {
                greeting
                inputCard
                quickScenes
                recentPeople
                recentRecords
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("分析")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("帮助")
            }
        }
        .sheet(isPresented: $showHelp) {
            NavigationStack {
                List {
                    Section("怎样获得更贴近实际的分析") {
                        Label("尽量保留前后文", systemImage: "text.bubble")
                        Label("说明双方关系和权力差", systemImage: "person.line.dotted.person.fill")
                        Label("先决定希望达到的结果", systemImage: "scope")
                    }
                    Section {
                        SafetyDisclaimer()
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
                .navigationTitle("使用帮助")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showHelp = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var greeting: some View {
        HStack(spacing: 12) {
            AvatarView(symbol: "person.crop.circle.fill", size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(greetingText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("今天遇到了什么沟通问题？")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("今日剩余")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(store.remainingAnalyses) 次")
                    .font(.headline)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Label("把聊天发给我看看", systemImage: "sparkles")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("支持截图、文字和模板化描述")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                homeAction("上传聊天截图", symbol: "photo.on.rectangle.angled", mode: .screenshot, prominent: true)
                HStack(spacing: 10) {
                    homeAction("粘贴聊天", symbol: "doc.on.clipboard", mode: .text)
                    homeAction("描述一件事", symbol: "square.and.pencil", mode: .template)
                }
            }
        }
        .padding(18)
        .appCard(cornerRadius: 24)
    }

    @ViewBuilder
    private func homeAction(_ title: String, symbol: String, mode: InputMode, prominent: Bool = false) -> some View {
        if prominent {
            Button {
                store.prepareNewAnalysis(mode: mode)
                store.analysisPath.append(.newAnalysis(mode, nil))
            } label: {
                Label(title, systemImage: symbol)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        } else {
            Button {
                store.prepareNewAnalysis(mode: mode)
                store.analysisPath.append(.newAnalysis(mode, nil))
            } label: {
                Label(title, systemImage: symbol)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
        }
    }

    private var quickScenes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("常用场景")
                .font(.title3)
                .fontWeight(.semibold)
            LazyVGrid(columns: sceneColumns, spacing: 12) {
                ForEach(QuickScene.allCases) { scene in
                    Button {
                        store.prepareNewAnalysis(mode: .template, scene: scene)
                        store.analysisPath.append(.newAnalysis(.template, scene))
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: scene.symbol)
                                .symbolRenderingMode(.hierarchical)
                            Text(scene.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    @ViewBuilder
    private var recentPeople: some View {
        if !store.people.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("最近人物")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Spacer()
                    Button("查看全部") { store.selectedTab = .people }
                        .font(.subheadline)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(store.people.prefix(5)) { person in
                            Button {
                                store.startAnalysis(for: person)
                            } label: {
                                VStack(spacing: 8) {
                                    AvatarView(symbol: person.avatarSymbol, size: 54)
                                    Text(person.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(person.relation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 104, height: 126)
                                .appCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentRecords: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最近记录")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                if !store.records.isEmpty {
                    Button("查看全部") { store.selectedTab = .records }
                        .font(.subheadline)
                }
            }

            if store.records.isEmpty {
                ContentUnavailableView {
                    Label("还没有分析记录", systemImage: "sparkles")
                } description: {
                    Text("上传一段聊天，看看 AI 能帮你发现哪些沟通信号。")
                } actions: {
                    Button("试试示例") {
                        store.prepareNewAnalysis(mode: .template, scene: .replyToLeader)
                        store.analysisPath.append(.newAnalysis(.template, .replyToLeader))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .appCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.records.prefix(3).enumerated()), id: \.element.id) { index, record in
                        Button {
                            store.selectedTab = .records
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "text.bubble.fill")
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.originalText)
                                        .lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Text("\(record.personName) · \(record.date.formatted(.relative(presentation: .named)))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding()
                        }
                        .buttonStyle(.plain)
                        if index < min(2, store.records.count - 1) {
                            Divider().padding(.leading, 48)
                        }
                    }
                }
                .appCard()
            }
        }
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 0..<6: "夜深了"
        case 6..<12: "上午好"
        case 12..<18: "下午好"
        default: "晚上好"
        }
    }
}
