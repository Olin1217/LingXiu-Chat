import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var store
    @State private var page = 0
    let onComplete: () -> Void

    private let pages = [
        OnboardingPage(
            symbol: "text.bubble.fill",
            title: "看懂别人没有直接说出口的话",
            message: "结合关系、场景、语气和上下文，分析对方可能的真实关注点。"
        ),
        OnboardingPage(
            symbol: "point.3.connected.trianglepath.dotted",
            title: "先选择你的目的，再生成回复",
            message: "接受、拒绝、解释、争取时间或保持距离，不同目的需要不同表达。"
        ),
        OnboardingPage(
            symbol: "person.text.rectangle.fill",
            title: "建立你的人物沟通档案",
            message: "记录领导、客户、同事和亲人的沟通特点，让建议越来越贴合实际。"
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("灵嗅", systemImage: "bubble.left.and.bubble.right.fill")
                    .font(.headline)
                Spacer()
                Button("跳过", action: onComplete)
                    .opacity(page == pages.count - 1 ? 0 : 1)
            }
            .padding()

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    VStack(spacing: 28) {
                        Spacer()
                        Image(systemName: item.symbol)
                            .font(.system(size: 74, weight: .medium))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)

                        VStack(spacing: 14) {
                            Text(item.title)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.center)
                            Text(item.message)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 28)
                        Spacer()
                    }
                    .tag(index)
                    .accessibilityElement(children: .combine)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            VStack(spacing: 12) {
                Button {
                    if page < pages.count - 1 {
                        withAnimation(.smooth) { page += 1 }
                    } else {
                        onComplete()
                    }
                } label: {
                    Text(page == pages.count - 1 ? "开始体验" : "下一步")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .primaryActionStyle()

                if page == pages.count - 1 {
                    Button("先看看示例") {
                        store.prepareNewAnalysis(mode: .template, scene: .replyToLeader)
                        store.analysisPath = [.newAnalysis(.template, .replyToLeader)]
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                }

                Text("可先以游客身份体验，所有示例数据只保存在本机。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AppTheme.pageBackground)
    }
}

private struct OnboardingPage {
    let symbol: String
    let title: String
    let message: String
}
