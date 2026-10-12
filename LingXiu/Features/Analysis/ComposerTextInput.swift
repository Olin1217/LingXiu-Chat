import SwiftUI
import UIKit

enum ComposerInputLayout: Equatable {
    case compact
    case multiline
    case expanded

    var maximumEditorHeight: CGFloat? {
        switch self {
        case .compact:
            58
        case .multiline:
            176
        case .expanded:
            nil
        }
    }
}

struct ComposerTextMetrics: Equatable {
    var contentHeight: CGFloat = 22
    var lineCount: Int = 1
    var isVerticallyScrollable = false
}

@MainActor
enum ComposerLayoutPolicy {
    static let expansionLineThreshold = 5

    static func inlineTokenHeight(
        font: UIFont = .preferredFont(forTextStyle: .body)
    ) -> CGFloat {
        ceil(font.lineHeight)
    }

    static func showsPlaceholder(
        text: String,
        placeholder: String,
        isFocused: Bool
    ) -> Bool {
        text.isEmpty && !placeholder.isEmpty && !isFocused
    }

    static func requiresMultiline(
        text: String,
        compactWidth: CGFloat,
        font: UIFont = .preferredFont(forTextStyle: .body)
    ) -> Bool {
        guard !text.isEmpty else { return false }
        if text.contains("\n") { return true }

        let usableWidth = max(compactWidth, 44)
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: usableWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(bounds.height) > ceil(font.lineHeight * 1.15)
    }

    static func showsExpansionControl(for metrics: ComposerTextMetrics) -> Bool {
        metrics.lineCount >= expansionLineThreshold || metrics.isVerticallyScrollable
    }

    static func usesExpandedCard(
        isFocused: Bool,
        text: String,
        compactWidth: CGFloat,
        font: UIFont = .preferredFont(forTextStyle: .body)
    ) -> Bool {
        isFocused || requiresMultiline(
            text: text,
            compactWidth: compactWidth,
            font: font
        )
    }
}

struct ComposerTextInput: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var selection: NSRange
    let placeholder: String
    let layout: ComposerInputLayout
    let onSubmit: () -> Void
    let onDeleteToken: (() -> Void)?
    let onMetricsChange: (ComposerTextMetrics) -> Void
    var inlineTokenSize: CGSize? = nil

    var body: some View {
        ZStack(alignment: layout == .compact ? .leading : .topLeading) {
            if ComposerLayoutPolicy.showsPlaceholder(
                text: text,
                placeholder: placeholder,
                isFocused: isFocused
            ) {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.72))
                    .frame(maxWidth: .infinity, alignment: layout == .compact ? .leading : .topLeading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            BackspaceAwareTextViewRepresentable(
                text: $text,
                isFocused: $isFocused,
                selection: $selection,
                layout: layout,
                onSubmit: onSubmit,
                onDeleteToken: onDeleteToken,
                onMetricsChange: onMetricsChange,
                inlineTokenSize: inlineTokenSize
            )
            .accessibilityLabel(placeholder.isEmpty ? "输入沟通内容" : placeholder)
        }
    }
}

struct BackspaceAwareTextViewRepresentable: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    @Binding var selection: NSRange
    let layout: ComposerInputLayout
    let onSubmit: () -> Void
    let onDeleteToken: (() -> Void)?
    let onMetricsChange: (ComposerTextMetrics) -> Void
    var inlineTokenSize: CGSize? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> BackspaceAwareTextView {
        // Exclusion paths are a TextKit 1 layout feature. Opt in at creation
        // time so UIKit does not switch engines after the editor is on screen.
        let textView = BackspaceAwareTextView(usingTextLayoutManager: false)
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.contentInsetAdjustmentBehavior = .never
        textView.returnKeyType = .default
        textView.enablesReturnKeyAutomatically = false
        textView.scrollsToTop = false
        textView.alwaysBounceVertical = false
        textView.showsVerticalScrollIndicator = false
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.onCommandSubmit = onSubmit
        textView.onFocusRequest = { [weak coordinator = context.coordinator] in
            coordinator?.requestFocus()
        }
        textView.onMetricsChange = { [weak coordinator = context.coordinator] metrics in
            coordinator?.report(metrics)
        }
        context.coordinator.lastPublishedText = text
        apply(layout: layout, to: textView)
        apply(inlineTokenSize: inlineTokenSize, to: textView)
        return textView
    }

    func updateUIView(_ textView: BackspaceAwareTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.isSynchronizingFromSwiftUI = true
        defer { context.coordinator.isSynchronizingFromSwiftUI = false }
        textView.onDeleteBackwardAtStart = onDeleteToken
        textView.onCommandSubmit = onSubmit
        apply(layout: layout, to: textView)
        apply(inlineTokenSize: inlineTokenSize, to: textView)

        if textView.text != text {
            // UIKit delivers textViewDidChange immediately, while SwiftUI
            // applies the resulting binding update on a later run-loop pass.
            // During rapid typing the representable can therefore be updated
            // with the previous value (for example "A" while UITextView
            // already contains "Ab"). Reassigning that stale value here
            // drops every character after the first one. If the current text
            // is the last value published by this editor, keep UIKit's live
            // buffer and let the binding catch up instead. A different value
            // still represents an external change (clear, OCR, restoring a
            // conversation) and is applied normally.
            let isLiveEditingBuffer = textView.isFirstResponder
                && textView.markedTextRange == nil
                && textView.text == context.coordinator.lastPublishedText
            if !isLiveEditingBuffer {
                textView.text = text
                context.coordinator.lastPublishedText = text
                let upperBound = (text as NSString).length
                let location = min(selection.location, upperBound)
                let length = min(selection.length, upperBound - location)
                textView.selectedRange = NSRange(location: location, length: length)
                textView.invalidateIntrinsicContentSize()
                textView.setNeedsLayout()
            }
        } else if textView.markedTextRange == nil,
                  textView.selectedRange != selection {
            let upperBound = (text as NSString).length
            let location = min(selection.location, upperBound)
            let length = min(selection.length, upperBound - location)
            textView.selectedRange = NSRange(location: location, length: length)
        }

        if isFocused && !textView.isFirstResponder {
            context.coordinator.requestInputFocus(for: textView)
        } else if !isFocused && textView.isFirstResponder {
            context.coordinator.cancelPendingFocusRequest()
            textView.resignFirstResponder()
        }
    }

    static func dismantleUIView(_ uiView: BackspaceAwareTextView, coordinator: Coordinator) {
        coordinator.cancelPendingFocusRequest()
        coordinator.cancelPendingTextDelivery()
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: BackspaceAwareTextView,
        context: Context
    ) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0 else { return nil }

        if layout == .expanded {
            uiView.isScrollEnabled = true
            return CGSize(
                width: width,
                height: proposal.height ?? max(uiView.bounds.height, 320)
            )
        }

        let fittingSize = uiView.sizeThatFits(
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        )
        let minimumHeight: CGFloat = layout == .compact ? 58 : 44
        let maximumHeight = layout.maximumEditorHeight ?? fittingSize.height
        let height = min(max(fittingSize.height, minimumHeight), maximumHeight)
        uiView.isScrollEnabled = fittingSize.height > maximumHeight + 0.5
        return CGSize(width: width, height: height)
    }

    private func apply(layout: ComposerInputLayout, to textView: BackspaceAwareTextView) {
        guard textView.composerLayout != layout else { return }
        textView.composerLayout = layout

        switch layout {
        case .compact:
            textView.textContainerInset = UIEdgeInsets(top: 18, left: 0, bottom: 18, right: 0)
            textView.isScrollEnabled = false
        case .multiline:
            textView.textContainerInset = .zero
        case .expanded:
            textView.textContainerInset = .zero
            textView.contentInset = .zero
            textView.scrollIndicatorInsets = .zero
            textView.isScrollEnabled = true
            textView.showsVerticalScrollIndicator = true
        }

        textView.invalidateIntrinsicContentSize()
        textView.setNeedsLayout()
    }

    private func apply(inlineTokenSize: CGSize?, to textView: BackspaceAwareTextView) {
        guard textView.inlineTokenSize != inlineTokenSize else { return }
        textView.inlineTokenSize = inlineTokenSize

        if let inlineTokenSize,
           inlineTokenSize.width > 0,
           inlineTokenSize.height > 0 {
            let exclusionRect = CGRect(origin: .zero, size: inlineTokenSize)
            textView.textContainer.exclusionPaths = [
                UIBezierPath(
                    roundedRect: exclusionRect,
                    cornerRadius: min(inlineTokenSize.height / 2, 12)
                )
            ]
        } else {
            textView.textContainer.exclusionPaths = []
        }

        textView.layoutManager.invalidateLayout(
            forCharacterRange: NSRange(location: 0, length: textView.textStorage.length),
            actualCharacterRange: nil
        )
        textView.invalidateIntrinsicContentSize()
        textView.setNeedsLayout()
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: BackspaceAwareTextViewRepresentable
        var isSynchronizingFromSwiftUI = false
        /// The most recent value emitted by UITextView itself. SwiftUI may
        /// briefly render an older binding value while a user is typing; this
        /// lets updateUIView distinguish that transient lag from a real
        /// external text change.
        var lastPublishedText = ""
        private var lastDeliveredMetrics: ComposerTextMetrics?
        private var pendingMetrics: ComposerTextMetrics?
        private var isMetricsDeliveryScheduled = false
        private var focusTask: Task<Void, Never>?
        private var pendingText: String?
        private var pendingSelection: NSRange?
        private var textDeliveryTask: Task<Void, Never>?

        init(parent: BackspaceAwareTextViewRepresentable) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused { parent.isFocused = true }
        }

        func requestFocus() {
            if !parent.isFocused { parent.isFocused = true }
        }

        func requestInputFocus(for textView: BackspaceAwareTextView) {
            guard focusTask == nil else { return }

            focusTask = Task { @MainActor [weak self, weak textView] in
                defer { self?.focusTask = nil }

                // A token selection changes the composer from its compact
                // layout to the expanded editing layout in the same update
                // that asks for focus. On iPhone 17 Pro, the text view can
                // take a few layout passes to reattach to its window. Keep
                // retrying for a short, bounded interval so the keyboard is
                // reliably presented without leaving a task running forever.
                for _ in 0 ..< 20 {
                    guard !Task.isCancelled,
                          let self,
                          self.parent.isFocused,
                          let textView else { return }

                    if textView.requestInputFocus() {
                        await Task.yield()
                        textView.revealSelectionIfNeeded()
                        return
                    }

                    try? await Task.sleep(for: .milliseconds(50))
                }
            }
        }

        func cancelPendingFocusRequest() {
            focusTask?.cancel()
            focusTask = nil
        }

        func cancelPendingTextDelivery() {
            textDeliveryTask?.cancel()
            textDeliveryTask = nil
            pendingText = nil
            pendingSelection = nil
        }

        private func scheduleTextDelivery() {
            textDeliveryTask?.cancel()
            textDeliveryTask = Task { @MainActor [weak self] in
                // Coalesce a burst of UIKit editing callbacks. Updating the
                // SwiftUI binding synchronously for every keystroke causes a
                // full composer reconciliation while the next key is still
                // being delivered, which is visible as dropped characters on
                // iOS 26's simulator and hardware keyboards.
                try? await Task.sleep(for: .milliseconds(30))
                guard !Task.isCancelled, let self,
                      let pendingText = self.pendingText else { return }
                self.pendingText = nil
                let pendingSelection = self.pendingSelection
                self.pendingSelection = nil
                self.lastPublishedText = pendingText
                self.parent.text = pendingText
                if let pendingSelection {
                    self.parent.selection = pendingSelection
                }
                self.textDeliveryTask = nil
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused { parent.isFocused = false }
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSynchronizingFromSwiftUI else { return }
            lastPublishedText = textView.text
            pendingText = textView.text
            pendingSelection = textView.selectedRange
            scheduleTextDelivery()
            textView.invalidateIntrinsicContentSize()
            textView.setNeedsLayout()
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isSynchronizingFromSwiftUI,
                  textView.markedTextRange == nil else { return }
            if parent.selection != textView.selectedRange {
                pendingSelection = textView.selectedRange
                scheduleTextDelivery()
            }
        }

        func report(_ metrics: ComposerTextMetrics) {
            guard metrics != pendingMetrics,
                  metrics != lastDeliveredMetrics else { return }

            pendingMetrics = metrics
            guard !isMetricsDeliveryScheduled else { return }
            isMetricsDeliveryScheduled = true

            // `layoutSubviews` can run while SwiftUI is reconciling this
            // representable. Delivering the binding change on the next main
            // run-loop pass avoids mutating SwiftUI state during that update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isMetricsDeliveryScheduled = false
                guard let pendingMetrics = self.pendingMetrics,
                      pendingMetrics != self.lastDeliveredMetrics else { return }
                self.lastDeliveredMetrics = pendingMetrics
                self.parent.onMetricsChange(pendingMetrics)
            }
        }
    }
}

final class BackspaceAwareTextView: UITextView {
    var onDeleteBackwardAtStart: (() -> Void)?
    var onCommandSubmit: (() -> Void)?
    var onFocusRequest: (() -> Void)?
    var onMetricsChange: ((ComposerTextMetrics) -> Void)?
    var composerLayout: ComposerInputLayout?
    var inlineTokenSize: CGSize?

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: "发送",
                action: #selector(submitWithHardwareKeyboard),
                input: "\r",
                modifierFlags: .command
            )
        ]
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }

        let fittingHeight = sizeThatFits(
            CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        ).height
        let lineHeight = font?.lineHeight ?? 22
        let textHeight = max(
            fittingHeight - textContainerInset.top - textContainerInset.bottom,
            lineHeight
        )
        let lineCount = max(Int(ceil(textHeight / lineHeight)), 1)

        if composerLayout == .expanded {
            let visibleHeight = max(bounds.height - contentInset.top - contentInset.bottom, 1)
            if bounds.height > 0 {
                let shouldScroll = fittingHeight > visibleHeight + 1
                if isScrollEnabled != shouldScroll {
                    isScrollEnabled = shouldScroll
                }
                if !shouldScroll, contentOffset != .zero {
                    setContentOffset(.zero, animated: false)
                }
            }
        }

        let maximumHeight = composerLayout?.maximumEditorHeight
        let scrollable = maximumHeight.map { fittingHeight > $0 + 0.5 } ?? false
        onMetricsChange?(
            ComposerTextMetrics(
                contentHeight: fittingHeight,
                lineCount: max(lineCount, 1),
                isVerticallyScrollable: scrollable
            )
        )
    }

    @discardableResult
    func requestInputFocus() -> Bool {
        onFocusRequest?()
        guard window != nil else { return false }
        return becomeFirstResponder()
    }

    /// Keeps short expanded drafts anchored at the top while still revealing
    /// the insertion point for genuinely scrollable drafts. Calling
    /// `scrollRangeToVisible` before the presented editor has a real viewport
    /// can otherwise leave the text several screen-heights off canvas.
    func revealSelectionIfNeeded() {
        guard composerLayout == .expanded,
              bounds.width > 0,
              bounds.height > 0 else { return }

        layoutIfNeeded()

        let measuredHeight = sizeThatFits(
            CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude)
        ).height
        let visibleHeight = max(bounds.height - contentInset.top - contentInset.bottom, 1)

        guard measuredHeight > visibleHeight + 1 else {
            if contentOffset != .zero {
                setContentOffset(.zero, animated: false)
            }
            return
        }

        scrollRangeToVisible(selectedRange)
        let minimumY = -adjustedContentInset.top
        let maximumY = max(
            minimumY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        let clampedY = min(max(contentOffset.y, minimumY), maximumY)
        if abs(contentOffset.y - clampedY) > 0.5 {
            setContentOffset(CGPoint(x: 0, y: clampedY), animated: false)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !isFirstResponder {
            requestInputFocus()
        } else {
            onFocusRequest?()
        }
        super.touchesBegan(touches, with: event)
    }

    override func deleteBackward() {
        let isAtStart = selectedRange.location == 0 && selectedRange.length == 0
        if isAtStart,
           markedTextRange == nil,
           let onDeleteBackwardAtStart {
            onDeleteBackwardAtStart()
            return
        }

        super.deleteBackward()
    }

    @objc private func submitWithHardwareKeyboard() {
        onCommandSubmit?()
    }
}
