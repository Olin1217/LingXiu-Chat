import SwiftUI
import UIKit

enum AppTheme {
    static let pageBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let subtleFill = Color(uiColor: .tertiarySystemFill)
    static let warning = Color(uiColor: .systemOrange)
    static let success = Color(uiColor: .systemGreen)
}

extension View {
    func appCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    func primaryActionStyle() -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}
