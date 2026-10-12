import SwiftUI
import UIKit

enum AppTheme {
    static let pureWhite = Color("PureWhite")
    static let deepBlack = Color("DeepBlack")
    static let neutralGray = Color("NeutralGray")
    static let accent = Color("AccentColor")

    // Use UIKit's built-in dynamic system colors directly. A custom
    // `UIColor(dynamicProvider:)` closure inherits the app target's
    // MainActor isolation under Swift 6, but SwiftUI can resolve colors on
    // its AsyncRenderer thread. That mismatch causes a libdispatch assertion
    // during keyboard/search dismissal on iOS 26.1.
    static let pageBackground = Color(uiColor: .systemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    static let primaryText = Color(uiColor: .label)
    static let secondaryText = neutralGray
    static let cardBackground = neutralGray.opacity(0.10)
    static let subtleFill = neutralGray.opacity(0.18)
    static let messageFill = neutralGray.opacity(0.14)
    static let separator = neutralGray.opacity(0.38)
    static let warning = accent
    static let success = primaryText

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


    @ViewBuilder
    func composerSurface() -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
    }

    func dismissesKeyboardOnBackgroundTap() -> some View {
        background(KeyboardDismissTapBridge().allowsHitTesting(false))
    }

    /// A keyboard owned by a presented editor must not resize the screen behind
    /// that editor. The presented sheet still receives the normal keyboard safe
    /// area and remains fully interactive.
    @ViewBuilder
    func preservesBackgroundLayoutWhileKeyboardPresented(_ isPresented: Bool) -> some View {
        if isPresented {
            ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            self
        }
    }
}

private struct KeyboardDismissTapBridge: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        installRecognizer(from: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        installRecognizer(from: uiView, coordinator: context.coordinator)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstall()
    }

    private func installRecognizer(from view: UIView, coordinator: Coordinator) {
        DispatchQueue.main.async {
            coordinator.install(from: view)
        }
    }

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var installedView: UIView?
        private lazy var recognizer: UITapGestureRecognizer = {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(didTap))
            recognizer.cancelsTouchesInView = false
            recognizer.delegate = self
            return recognizer
        }()

        func install(from sourceView: UIView) {
            guard let window = sourceView.window, installedView !== window else { return }
            uninstall()
            window.addGestureRecognizer(recognizer)
            installedView = window
        }

        func uninstall() {
            installedView?.removeGestureRecognizer(recognizer)
            installedView = nil
        }

        @objc private func didTap() {
            installedView?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var touchedView = touch.view
            while let current = touchedView {
                if current is UITextField || current is UITextView {
                    return false
                }
                touchedView = current.superview
            }
            return true
        }
    }
}
