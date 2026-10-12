import PhotosUI
import SwiftUI
import UIKit

struct NewAnalysisView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedMode: InputMode
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isRecognizing = false
    @State private var showCamera = false
    @State private var cameraImageData: Data?
    @State private var redactionTarget: RedactionTarget?
    @State private var didPrepare = false
    let scene: QuickScene?

    init(initialMode: InputMode, scene: QuickScene?) {
        _selectedMode = State(initialValue: initialMode)
        self.scene = scene
    }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("输入方式", selection: $selectedMode) {
                    ForEach(InputMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedMode {
                case .screenshot:
                    screenshotInput
                case .text:
                    textInput
                case .template:
                    templateInput
                }
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(AppTheme.pageBackground)
        .navigationTitle("新建分析")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                store.draft.inputMode = selectedMode
                store.analysisPath.append(.supplement)
            } label: {
                Text("继续")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .primaryActionStyle()
            .disabled(!store.draft.hasUsableInput)
            .padding()
            .background(.bar)
        }
        .onChange(of: selectedMode) { _, newValue in
            store.draft.inputMode = newValue
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task { await loadPhotoItems(newItems) }
        }
        .onChange(of: cameraImageData) { _, data in
            guard let data else { return }
            Task { await importImages([data], replacingExisting: false) }
        }
        .sheet(isPresented: $showCamera) {
            CameraPicker(imageData: $cameraImageData)
                .ignoresSafeArea()
        }
        .sheet(item: $redactionTarget) { target in
            ManualRedactionView(data: target.data) { redactedData in
                guard store.draft.screenshotData.indices.contains(target.index) else { return }
                store.draft.screenshotData[target.index] = redactedData
            }
        }
        .onAppear {
            guard !didPrepare else { return }
            didPrepare = true
            if scene != nil || store.draft.inputMode != selectedMode {
                store.prepareNewAnalysis(mode: selectedMode, scene: scene)
            }
        }
    }

    private var screenshotInput: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("添加聊天截图")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("支持多张连续截图，建议保留前后文。图片只在设备上进行文字识别。")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("隐私处理", systemImage: "hand.raised.fill")
                        .font(.headline)
                    Picker("隐私处理", selection: Binding(
                        get: { store.draft.privacyMode },
                        set: { store.draft.privacyMode = $0 }
                    )) {
                        Text("自动隐藏").tag("自动隐藏")
                        Text("手动打码").tag("手动打码")
                        Text("保持原图").tag("保持原图")
                    }
                    .pickerStyle(.segmented)
                    Text(privacyDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images) {
                    Label("从相册选择", systemImage: "photo.on.rectangle.angled")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)

                HStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("拍照", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)

                    Button(action: pasteFromClipboard) {
                        Label("剪贴板", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity, minHeight: 42)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .appCard()

            if !store.draft.screenshotData.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("截图顺序")
                        .font(.headline)
                    ForEach(Array(store.draft.screenshotData.enumerated()), id: \.offset) { index, data in
                        HStack(spacing: 12) {
                            if let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 58, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .clipped()
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("截图 \(index + 1)")
                                    .font(.headline)
                                Text("可调整顺序或删除")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                moveScreenshot(at: index, direction: -1)
                            } label: {
                                Image(systemName: "arrow.up")
                            }
                            .disabled(index == 0)
                            Button {
                                moveScreenshot(at: index, direction: 1)
                            } label: {
                                Image(systemName: "arrow.down")
                            }
                            .disabled(index == store.draft.screenshotData.count - 1)
                            Button(role: .destructive) {
                                store.draft.screenshotData.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            if store.draft.privacyMode == "手动打码" {
                                Button {
                                    redactionTarget = RedactionTarget(index: index, data: data)
                                } label: {
                                    Image(systemName: "highlighter")
                                }
                                .accessibilityLabel("手动打码截图 \(index + 1)")
                            }
                        }
                        .padding(12)
                        .appCard(cornerRadius: 16)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("OCR 识别结果")
                        .font(.headline)
                    Spacer()
                    if isRecognizing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                TextEditor(text: Binding(
                    get: { store.draft.conversationText },
                    set: { store.draft.conversationText = $0 }
                ))
                .frame(minHeight: 180)
                .padding(8)
                .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text("识别有误时可直接修改。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var textInput: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("粘贴聊天内容")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("可包含说话人、时间、表情和前后文，最多 10,000 字。")
                    .foregroundStyle(.secondary)
            }

            TextEditor(text: Binding(
                get: { store.draft.conversationText },
                set: { store.draft.conversationText = String($0.prefix(10_000)) }
            ))
            .frame(minHeight: 280)
            .padding(10)
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topLeading) {
                if store.draft.conversationText.isEmpty {
                    Text("例如：\n领导：这个方案感觉还需要再打磨一下。\n我：好的。\n领导：你再多想想。")
                        .foregroundStyle(.tertiary)
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Button(action: pasteText) {
                    Label("从剪贴板粘贴", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("\(store.draft.conversationText.count) / 10,000")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Button("清空", role: .destructive) {
                    store.draft.conversationText = ""
                }
                .disabled(store.draft.conversationText.isEmpty)
            }
        }
    }

    private var templateInput: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("描述这次沟通")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("没有完整聊天记录也没关系，补充关键事实即可。")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                LabeledContent("对方是谁") {
                    Picker("对方是谁", selection: Binding(
                        get: { store.draft.relation },
                        set: { store.draft.relation = $0 }
                    )) {
                        ForEach(["领导", "老板", "同事", "下属", "客户", "合作方", "亲人", "恋人", "朋友", "其他"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                }

                Divider()
                Text("发生在什么场合")
                    .font(.headline)
                FlowLayout {
                    ForEach(["私聊", "群聊", "当面交流", "电话", "会议", "工作汇报", "商务谈判", "家庭沟通"], id: \.self) { item in
                        SelectableChip(title: item, isSelected: store.draft.occasions.contains(item)) {
                            toggle(item, in: &store.draft.occasions)
                        }
                    }
                }
            }
            .padding()
            .appCard()

            textFieldCard(title: "对方说了什么", placeholder: "尽量保留原话、表情和标点", text: Binding(
                get: { store.draft.conversationText },
                set: { store.draft.conversationText = $0 }
            ))

            textFieldCard(title: "事情背景", placeholder: "这次沟通之前发生了什么？", text: Binding(
                get: { store.draft.background },
                set: { store.draft.background = $0 }
            ))

            multiSelectCard(
                title: "你最担心什么",
                items: ["对方不满意", "不知道如何拒绝", "害怕关系变差", "不知道是否要追问", "担心显得不专业", "不理解真实目的"],
                selection: Binding(get: { store.draft.worries }, set: { store.draft.worries = $0 })
            )

            multiSelectCard(
                title: "你希望得到什么",
                items: ["分析对方意图", "判断关系状态", "给出行动建议", "生成回复", "检查准备发送的话"],
                selection: Binding(get: { store.draft.desiredOutputs }, set: { store.draft.desiredOutputs = $0 })
            )
        }
    }

    private func textFieldCard(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            TextField(placeholder, text: text, axis: .vertical)
                .lineLimit(4...8)
                .textFieldStyle(.plain)
        }
        .padding()
        .appCard()
    }

    private func multiSelectCard(title: String, items: [String], selection: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            FlowLayout {
                ForEach(items, id: \.self) { item in
                    SelectableChip(title: item, isSelected: selection.wrappedValue.contains(item)) {
                        var updated = selection.wrappedValue
                        toggle(item, in: &updated)
                        selection.wrappedValue = updated
                    }
                }
            }
        }
        .padding()
        .appCard()
    }

    private func toggle(_ item: String, in set: inout Set<String>) {
        if set.contains(item) {
            set.remove(item)
        } else {
            set.insert(item)
        }
    }

    private func pasteText() {
        if let text = UIPasteboard.general.string {
            store.draft.conversationText = String(text.prefix(10_000))
        }
    }

    private func pasteFromClipboard() {
        if let image = UIPasteboard.general.image, let data = image.jpegData(compressionQuality: 0.9) {
            Task { await importImages([data], replacingExisting: false) }
        } else {
            pasteText()
        }
    }

    private func loadPhotoItems(_ items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(data)
            }
        }
        guard !loaded.isEmpty else { return }
        await importImages(loaded, replacingExisting: true)
    }

    private func importImages(_ images: [Data], replacingExisting: Bool) async {
        isRecognizing = true
        var recognized: [String] = []
        for data in images {
            let text = await OCRService.recognize(data: data)
            if !text.isEmpty { recognized.append(text) }
        }
        var storedImages = images
        if store.draft.privacyMode == "自动隐藏" {
            storedImages = []
            for data in images {
                storedImages.append(await PrivacyImageProcessor.automaticallyRedact(data: data))
            }
        }

        if replacingExisting {
            store.draft.screenshotData = storedImages
            if !recognized.isEmpty {
                store.draft.conversationText = recognized.joined(separator: "\n\n")
            }
        } else {
            store.draft.screenshotData.append(contentsOf: storedImages)
            if !recognized.isEmpty {
                let separator = store.draft.conversationText.isEmpty ? "" : "\n\n"
                store.draft.conversationText += separator + recognized.joined(separator: "\n\n")
            }
        }
        isRecognizing = false
    }

    private var privacyDescription: String {
        switch store.draft.privacyMode {
        case "自动隐藏": "导入时会遮挡顶部身份区、识别到的人脸和顶部昵称，请在提交前预览。"
        case "手动打码": "导入后点按每张截图旁的荧光笔按钮，手动遮挡敏感信息。"
        default: "保留原图，只建议在确认没有隐私信息时使用。"
        }
    }

    private func moveScreenshot(at index: Int, direction: Int) {
        let target = index + direction
        guard store.draft.screenshotData.indices.contains(index), store.draft.screenshotData.indices.contains(target) else { return }
        store.draft.screenshotData.swapAt(index, target)
    }
}

private struct RedactionTarget: Identifiable {
    let id = UUID()
    let index: Int
    let data: Data
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    @Binding var imageData: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker

        init(parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.imageData = image.jpegData(compressionQuality: 0.9)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
