import PhotosUI
import StoreKit
import SwiftUI
import UIKit

struct UserAvatarView: View {
    let profile: UserProfile
    var size: CGFloat = 48

    var body: some View {
        UserAvatarImage(data: profile.avatarData, size: size)
    }
}

private struct UserAvatarImage: View {
    let data: Data?
    let size: CGFloat

    var body: some View {
        Group {
            if let data,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: size, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .frame(width: size, height: size)
        .background(AppTheme.subtleFill, in: Circle())
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

private struct AccountAvatarPickerLabel: View {
    let data: Data?

    var body: some View {
        HStack(spacing: 14) {
            UserAvatarImage(data: data, size: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(data == nil ? "设置用户头像" : "更换用户头像")
                    .foregroundStyle(AppTheme.primaryText)
                Text("从照片中选择")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .contentShape(Rectangle())
    }
}

struct AccountCenterView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var avatarData: Data?
    @State private var avatarItem: PhotosPickerItem?
    @State private var didLoadProfile = false

    private var canSave: Bool {
        !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        let currentAvatarData = avatarData

        return NavigationStack {
            Form {
                Section("个人资料") {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        AccountAvatarPickerLabel(data: currentAvatarData)
                    }
                    .buttonStyle(.plain)

                    TextField("用户名", text: $displayName)
                        .textInputAutocapitalization(.never)
                        .onChange(of: displayName) { _, newValue in
                            let limited = String(newValue.prefix(UserProfile.maximumDisplayNameLength))
                            if limited != newValue {
                                displayName = limited
                            }
                        }
                        .accessibilityHint("最多输入 \(UserProfile.maximumDisplayNameLength) 个字符")
                }

                Section {
                    NavigationLink {
                        PointsPurchaseView()
                    } label: {
                        LabeledContent {
                            Text(lingXiuPointsText(store.userProfile.points))
                                .foregroundStyle(AppTheme.primaryText)
                        } label: {
                            Label {
                                Text("我的积分")
                            } icon: {
                                PointsBoneIcon(size: 22)
                            }
                        }
                    }
                } header: {
                    Text("灵嗅积分")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("关闭个人中心")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.updateUserProfile(
                            displayName: displayName,
                            avatarData: avatarData
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .onAppear {
                guard !didLoadProfile else { return }
                displayName = store.userProfile.displayName
                avatarData = store.userProfile.avatarData
                didLoadProfile = true
            }
            .onChange(of: avatarItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        avatarData = data
                    }
                }
            }
            .dismissesKeyboardOnBackgroundTap()
        }
    }
}

struct PointsPurchaseView: View {
    @Environment(AppStore.self) private var store
    @State private var isPurchasing = false
    @State private var purchaseMessage = ""
    @State private var showPurchaseSuccess = false

    private let packages = [
        PointPackage(points: 120, price: "¥6", note: "适合偶尔分析"),
        PointPackage(points: 360, price: "¥18", note: "适合日常使用"),
        PointPackage(points: 800, price: "¥38", note: "更高性价比")
    ]

    var body: some View {
        List {
            Section {
                LabeledContent("当前积分") {
                    Text(lingXiuPointsText(store.userProfile.points))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.tint)
                }
                .padding(.vertical, 6)
            }

            Section {
                ForEach(packages) { package in
                    Button {
                        purchase(package)
                    } label: {
                        HStack(spacing: 14) {
                            PointsBoneIcon(size: 40)
                                .background(AppTheme.subtleFill, in: Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(package.points) 积分")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.primaryText)
                                Text(package.note)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.secondaryText)
                            }

                            Spacer()
                            Text(package.price)
                                .font(.headline)
                                .foregroundStyle(AppTheme.primaryText)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)
                }
            } header: {
                Text("选择积分包")
            } footer: {
                Text("当前为开发测试购买流程，不会产生真实扣款。正式版本将接入 Apple App Store 内购。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("购买积分")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PointHistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("积分变化记录")
                .accessibilityHint("查看购买和使用积分的记录")
            }
        }
        .alert("积分已到账", isPresented: $showPurchaseSuccess) {
            Button("完成", role: .cancel) { }
        } message: {
            Text(purchaseMessage)
        }
    }

    private func purchase(_ package: PointPackage) {
        guard !isPurchasing else { return }
        isPurchasing = true

        Task { @MainActor in
            defer { isPurchasing = false }

            // Production builds can provide these StoreKit product IDs from
            // App Store Connect. The tap remains a single-step purchase: no
            // secondary confirmation dialog is inserted before Apple Pay.
            if let product = try? await Product.products(for: [package.productID]).first {
                do {
                    switch try await product.purchase() {
                    case .success(let verification):
                        guard case .verified(let transaction) = verification else {
                            purchaseMessage = "无法验证这笔购买，请稍后重试。"
                            return
                        }
                        await transaction.finish()
                        store.addPoints(
                            package.points,
                            title: "购买积分",
                            detail: "\(package.points) 积分包"
                        )
                        purchaseMessage = "已增加 \(package.points) 积分"
                        showPurchaseSuccess = true
                    case .pending:
                        purchaseMessage = "购买正在等待 App Store 处理。"
                    case .userCancelled:
                        break
                    @unknown default:
                        purchaseMessage = "购买暂时不可用，请稍后重试。"
                    }
                } catch {
                    purchaseMessage = "购买暂时不可用，请稍后重试。"
                }
                return
            }

            // No StoreKit products are bundled in this prototype yet. Keep a
            // clearly labelled local test path instead of pretending that a
            // real charge occurred.
            store.addPoints(
                package.points,
                title: "购买积分",
                detail: "\(package.points) 积分包"
            )
            purchaseMessage = "开发测试：已增加 \(package.points) 积分（未产生真实扣款）"
            showPurchaseSuccess = true
        }
    }
}

struct PointHistoryView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.pointTransactions.isEmpty {
                ContentUnavailableView(
                    "暂无积分变化",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("购买积分或完成沟通分析后，变化记录会显示在这里。")
                )
            } else {
                List {
                    ForEach(Array(store.pointTransactions.enumerated()), id: \.element.id) { index, transaction in
                        PointTransactionRow(transaction: transaction)
                            .listRowBackground(AppTheme.groupedBackground)
                            // Keep separators between transactions, but omit
                            // the decorative boundaries at the top and bottom.
                            .listRowSeparator(index == 0 ? .hidden : .visible, edges: .top)
                            .listRowSeparator(index == store.pointTransactions.count - 1 ? .hidden : .visible, edges: .bottom)
                    }
                }
                // Use the native flat list presentation so records are not
                // grouped into a rounded card, while keeping system separators.
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("积分变化记录")
        .navigationBarTitleDisplayMode(.inline)
        .background(AppTheme.groupedBackground)
    }
}

private struct PointTransactionRow: View {
    let transaction: PointTransaction

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppTheme.primaryText)
                if !transaction.detail.isEmpty {
                    Text(transaction.detail)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
                Text(transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 12)

            Text(transaction.amount >= 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(transaction.isCredit ? AppTheme.accent : AppTheme.primaryText)
                .accessibilityLabel(transaction.isCredit ? "增加 \(transaction.amount) 积分" : "减少 \(abs(transaction.amount)) 积分")
        }
        .padding(.vertical, 5)
        // Keep the native List separator aligned with the visible content,
        // rather than leaving an inset based on the removed status icon.
        .alignmentGuide(.listRowSeparatorLeading) { dimensions in
            dimensions[.leading]
        }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in
            dimensions[.trailing]
        }
    }
}

private struct PointPackage: Identifiable, Hashable {
    let points: Int
    let price: String
    let note: String

    var id: Int { points }

    var productID: String { "com.hualong.LingXiu.points\(points)" }
}
