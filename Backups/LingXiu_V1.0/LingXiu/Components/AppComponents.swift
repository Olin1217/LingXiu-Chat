import SwiftUI

struct AvatarView: View {
    let symbol: String
    var size: CGFloat = 48

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.48, weight: .medium))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(AppTheme.subtleFill, in: Circle())
            .accessibilityHidden(true)
    }
}

struct TagLabel: View {
    let text: String
    var color: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12), in: Capsule())
    }
}

struct LikelihoodBadge: View {
    let likelihood: Likelihood

    private var color: Color {
        switch likelihood {
        case .high: .green
        case .medium: .orange
        case .low, .insufficient: .secondary
        }
    }

    var body: some View {
        TagLabel(text: likelihood.rawValue, color: color)
            .accessibilityLabel("可能性：\(likelihood.rawValue)")
    }
}

struct SelectableChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? .accentColor : .secondary)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                widest = max(widest, rowWidth - spacing)
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        widest = max(widest, max(0, rowWidth - spacing))
        totalHeight += rowHeight
        return CGSize(width: min(maxWidth, widest), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct SafetyDisclaimer: View {
    var body: some View {
        Label {
            Text("AI 只能根据你提供的信息推测沟通信号，不能确定他人的真实心理。重要关系、法律、医疗、财务和人身安全问题，请结合现实证据和专业意见判断。")
        } icon: {
            Image(systemName: "info.circle.fill")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding()
        .background(AppTheme.subtleFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
