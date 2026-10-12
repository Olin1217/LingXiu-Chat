import PhotosUI
import SwiftUI
import UIKit

struct AnalysisHomeView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isRecognizing = false
    @State private var importMessage: String?
    @State private var showResult = false

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                intro
                imageInput
                textInput(text: $store.draft.conversationText)
                roleCardPicker(selection: $store.draft.selectedRoleCardID)
                analyzeButton
                privacyNote
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("灵嗅")
        .toolbar {
            if store.draft.hasUsableText || !store.draft.imageData.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        selectedPhotoItems = []
                        importMessage = nil
                        store.clearAnalysis(keepingInput: false)
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showResult) {
            AnalysisResultView()
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await loadPhotos(newItems) }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI 沟通分析", systemImage: "sparkles")
                .font(.title2)
                .fontWeight(.bold)
            Text("上传聊天截图，或直接输入聊天内容。灵嗅会分析可能的含义，并给出几个可以直接使用的回答。")
                .foregroundStyle(.secondary)
        }
    }

    private var imageInput: some View {
        let pickerTitle = store.draft.imageData.isEmpty ? "选择聊天图片" : "重新选择图片"

        return GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 3, matching: .images) {
                    Label(pickerTitle, systemImage: "photo.on.rectangle.angled")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRecognizing || store.isAnalyzing)

                if isRecognizing {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("正在识别图片中的文字…")
                            .foregroundStyle(.secondary)
                    }
                }

                if !store.draft.imageData.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(store.draft.imageData.enumerated()), id: \.offset) { _, data in
                                if let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 76, height: 96)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .clipped()
                                }
                            }
                        }
                    }
                }

                if let importMessage {
                    Text(importMessage)
                        .font(.footnote)
                        .foregroundStyle(store.draft.hasUsableText ? Color.secondary : Color.orange)
                }
            }
            .padding(.top, 4)
        } label: {
            Label("上传图片", systemImage: "photo")
                .font(.headline)
        }
    }

    private func textInput(text: Binding<String>) -> some View {
        GroupBox {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text("例如：\n领导：这个方案再优化一下。\n我：具体希望调整哪些部分？")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: text)
                    .frame(minHeight: 170)
                    .scrollContentBackground(.hidden)
            }
        } label: {
            Label("聊天内容", systemImage: "text.bubble")
                .font(.headline)
        }
    }

    private func roleCardPicker(selection: Binding<UUID?>) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Picker("分析对象", selection: selection) {
                    Text("不使用角色卡").tag(nil as UUID?)
                    ForEach(store.roleCards) { card in
                        Text("\(card.name) · \(card.relationship)")
                            .tag(card.id as UUID?)
                    }
                }

                if store.roleCards.isEmpty {
                    Button("去创建聊天角色卡") {
                        store.selectedTab = .roleCards
                    }
                    .font(.subheadline)
                } else if let roleCard = store.selectedRoleCard {
                    Text("将结合：\(roleCard.contextSummary)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .padding(.top, 4)
        } label: {
            Label("聊天角色卡（可选）", systemImage: "person.text.rectangle")
                .font(.headline)
        }
    }

    private var analyzeButton: some View {
        Button {
            Task {
                if await store.runAnalysis() {
                    showResult = true
                }
            }
        } label: {
            HStack {
                if store.isAnalyzing {
                    ProgressView()
                } else {
                    Image(systemName: "sparkles")
                }
                Text(store.isAnalyzing ? "正在分析…" : "开始 AI 分析")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .primaryActionStyle()
        .disabled(!store.draft.hasUsableText || store.isAnalyzing || isRecognizing)
    }

    private var privacyNote: some View {
        Label {
            Text("图片文字识别和当前演示分析均在设备本地完成。请在上传前遮挡姓名、头像、账号等敏感信息。")
        } icon: {
            Image(systemName: "hand.raised.fill")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else {
            store.draft.imageData = []
            return
        }

        isRecognizing = true
        importMessage = nil
        var loadedData: [Data] = []
        var recognizedText: [String] = []

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            loadedData.append(data)
            let text = await OCRService.recognize(data: data)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { recognizedText.append(text) }
        }

        store.draft.imageData = loadedData
        if recognizedText.isEmpty {
            importMessage = "没有识别到清晰文字，请换一张图片或在下方手动输入。"
        } else {
            let imported = recognizedText.joined(separator: "\n\n")
            if store.draft.conversationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                store.draft.conversationText = imported
            } else if !store.draft.conversationText.contains(imported) {
                store.draft.conversationText += "\n\n" + imported
            }
            importMessage = "已识别图片文字，你可以在下方继续修改。"
        }
        isRecognizing = false
    }
}

private struct AnalysisResultView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var copiedReplyID: UUID?

    var body: some View {
        Group {
            if let result = store.result {
                List {
                    Section("AI 分析") {
                        Text(result.summary)
                            .font(.body)
                    }

                    if let roleContext = result.roleContext {
                        Section("本次使用的角色卡") {
                            Text(roleContext)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("可能的含义") {
                        ForEach(result.possibleMeanings, id: \.self) { meaning in
                            Label(meaning, systemImage: "circle.fill")
                                .symbolRenderingMode(.hierarchical)
                        }
                    }

                    Section("沟通建议") {
                        ForEach(result.suggestions, id: \.self) { suggestion in
                            Label(suggestion, systemImage: "lightbulb.fill")
                        }
                    }

                    Section("回答选项") {
                        ForEach(store.replies) { reply in
                            VStack(alignment: .leading, spacing: 10) {
                                Text(reply.label)
                                    .font(.headline)
                                Text(reply.text)
                                    .textSelection(.enabled)
                                Text(reply.rationale)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Button {
                                    UIPasteboard.general.string = reply.text
                                    copiedReplyID = reply.id
                                } label: {
                                    Label(copiedReplyID == reply.id ? "已复制" : "复制回答", systemImage: copiedReplyID == reply.id ? "checkmark" : "doc.on.doc")
                                        .frame(maxWidth: .infinity, minHeight: 38)
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.vertical, 6)
                        }
                    }

                    Section {
                        Label("AI 只能根据已提供的信息给出可能性，不能确定他人的真实心理。重要关系和高风险决定请结合现实证据判断。", systemImage: "info.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView("还没有分析结果", systemImage: "sparkles")
            }
        }
        .navigationTitle("分析结果")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("修改输入") {
                    store.clearAnalysis()
                    dismiss()
                }
            }
        }
    }
}
