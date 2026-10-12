import SwiftUI
import UIKit

struct ManualRedactionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var marks: [RedactionMark] = []
    let data: Data
    let onSave: (Data) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("轻点头像、昵称或敏感信息添加遮挡。可以连续添加多处。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let image = UIImage(data: data) {
                    GeometryReader { proxy in
                        let rect = fittedRect(imageSize: image.size, containerSize: proxy.size)
                        ZStack {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: proxy.size.width, height: proxy.size.height)

                            ForEach(marks) { mark in
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(uiColor: .systemGray))
                                    .frame(width: rect.width * 0.24, height: max(22, rect.height * 0.064))
                                    .position(
                                        x: rect.minX + mark.x * rect.width,
                                        y: rect.minY + mark.y * rect.height
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            SpatialTapGesture()
                                .onEnded { value in
                                    guard rect.contains(value.location) else { return }
                                    marks.append(
                                        RedactionMark(
                                            x: (value.location.x - rect.minX) / rect.width,
                                            y: (value.location.y - rect.minY) / rect.height
                                        )
                                    )
                                }
                        )
                    }
                } else {
                    ContentUnavailableView("图片无法读取", systemImage: "photo.badge.exclamationmark")
                }

                HStack {
                    Button("撤销", systemImage: "arrow.uturn.backward") {
                        if !marks.isEmpty { marks.removeLast() }
                    }
                    .disabled(marks.isEmpty)
                    Spacer()
                    Text("已遮挡 \(marks.count) 处")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .background(AppTheme.pageBackground)
            .navigationTitle("手动打码")
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
                        onSave(PrivacyImageProcessor.manuallyRedact(data: data, marks: marks))
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(marks.isEmpty)
                    .accessibilityLabel("保存打码")
                }
            }
        }
    }

    private func fittedRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}
