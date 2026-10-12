import SwiftUI

struct RecordsListView: View {
    @Environment(AppStore.self) private var store
    @State private var searchText = ""
    @State private var filter = "全部"

    private let filters = ["全部", "职场", "商务", "情感", "家庭", "已收藏", "有反馈", "无反馈"]

    private var filteredRecords: [AnalysisRecord] {
        store.records.filter { record in
            let matchesSearch = searchText.isEmpty || record.originalText.localizedCaseInsensitiveContains(searchText) || record.personName.localizedCaseInsensitiveContains(searchText)
            let matchesFilter: Bool
            switch filter {
            case "已收藏": matchesFilter = record.isFavorite
            case "有反馈": matchesFilter = record.feedback != nil
            case "无反馈": matchesFilter = record.feedback == nil
            case "全部": matchesFilter = true
            default: matchesFilter = record.scene == filter
            }
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        List {
            if filteredRecords.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "还没有分析记录" : "没有匹配记录", systemImage: "clock.badge.questionmark")
                } description: {
                    Text("完成一次分析并复制回复后，记录会保存在这里。")
                } actions: {
                    Button("开始分析") { store.selectedTab = .analysis }
                        .buttonStyle(.borderedProminent)
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredRecords) { record in
                    NavigationLink {
                        RecordDetailView(recordID: record.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(record.personName)
                                    .font(.headline)
                                TagLabel(text: record.scene)
                                Spacer()
                                if record.isFavorite {
                                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                                }
                            }
                            Text(record.originalText)
                                .lineLimit(2)
                            HStack {
                                Text(record.goal)
                                Spacer()
                                Text(record.date.formatted(.relative(presentation: .named)))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("删除", role: .destructive) {
                            store.records.removeAll { $0.id == record.id }
                        }
                        Button(record.isFavorite ? "取消收藏" : "收藏") {
                            guard let index = store.records.firstIndex(where: { $0.id == record.id }) else { return }
                            store.records[index].isFavorite.toggle()
                        }
                        .tint(.yellow)
                    }
                }
            }
        }
        .navigationTitle("记录")
        .searchable(text: $searchText, prompt: "搜索人物或聊天内容")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("筛选", selection: $filter) {
                        ForEach(filters, id: \.self) { Text($0).tag($0) }
                    }
                } label: {
                    Label("筛选", systemImage: "line.3.horizontal.decrease")
                }
            }
        }
    }
}

struct RecordDetailView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedFeedback = ""
    let recordID: UUID

    private var record: AnalysisRecord? {
        store.records.first { $0.id == recordID }
    }

    private let feedbackOptions = ["对方接受了", "对方继续追问", "对方不满意", "没有回复", "关系缓和", "冲突加重", "还没有结果"]

    var body: some View {
        Group {
            if let record {
                List {
                    Section("原始输入") {
                        Text(record.originalText)
                            .textSelection(.enabled)
                        LabeledContent("人物", value: record.personName)
                        LabeledContent("场景", value: record.scene)
                        LabeledContent("时间", value: record.date.formatted(date: .long, time: .shortened))
                    }

                    Section("当时分析") {
                        Text(record.resultSummary)
                    }

                    Section("用户选择") {
                        LabeledContent("回应目标", value: record.goal)
                    }

                    Section("最终回复") {
                        Text(record.selectedReply)
                            .textSelection(.enabled)
                        ShareLink(item: record.selectedReply) {
                            Label("分享回复", systemImage: "square.and.arrow.up")
                        }
                    }

                    Section("这次沟通后来怎么样？") {
                        Picker("结果反馈", selection: $selectedFeedback) {
                            Text("暂不反馈").tag("")
                            ForEach(feedbackOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .onChange(of: selectedFeedback) { _, value in
                            guard !value.isEmpty else { return }
                            store.updateFeedback(recordID: recordID, feedback: value)
                        }
                        Text("反馈用于优化本机人物档案；你可以在隐私设置中关闭记录。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .navigationTitle("记录详情")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear { selectedFeedback = record.feedback ?? "" }
            } else {
                ContentUnavailableView("记录不存在", systemImage: "doc.questionmark")
            }
        }
    }
}
