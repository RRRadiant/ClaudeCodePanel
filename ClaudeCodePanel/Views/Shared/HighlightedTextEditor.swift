import SwiftUI
import AppKit

// MARK: - NSViewRepresentable wrapper for highlighted text editing

struct HighlightedTextEditor: NSViewRepresentable {
    @Binding var text: String
    var fileType: SyntaxFileType?
    var onChange: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 16, height: 16)

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Initial content
        if !text.isEmpty {
            textView.string = text
            applyHighlighting(to: textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Only update from binding if text differs (avoid loop)
        if textView.string != text && !context.coordinator.isEditing {
            textView.string = text
            applyHighlighting(to: textView)
        }

        // Update file type
        context.coordinator.fileType = fileType
    }

    private func applyHighlighting(to textView: NSTextView) {
        guard let fileType = fileType else { return }
        let highlighter = SyntaxHighlighter(fileType: fileType)
        let attributed = highlighter.highlight(textView.string)

        // Preserve cursor position
        let selectedRanges = textView.selectedRanges
        textView.textStorage?.setAttributedString(attributed)
        textView.selectedRanges = selectedRanges
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let parent: HighlightedTextEditor
        weak var textView: NSTextView?
        var fileType: SyntaxFileType?
        var isEditing = false

        init(_ parent: HighlightedTextEditor) {
            self.parent = parent
            self.fileType = parent.fileType
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }

            isEditing = true
            defer { isEditing = false }

            let newText = textView.string

            // Apply highlighting as user types
            if let ft = fileType {
                let highlighter = SyntaxHighlighter(fileType: ft)
                let selectedRanges = textView.selectedRanges
                let attributed = highlighter.highlight(newText)
                textView.textStorage?.setAttributedString(attributed)
                textView.selectedRanges = selectedRanges
            }

            // Update binding
            DispatchQueue.main.async { [weak self] in
                self?.parent.text = newText
                self?.parent.onChange?(newText)
            }
        }
    }
}
