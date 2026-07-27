import AppKit
import SwiftUI

struct RichTextEntryEditor: NSViewRepresentable {
    let entryID: Entry.ID
    @Binding var body: String
    @Binding var richTextData: Data?
    @Binding var height: CGFloat
    var focusedEntryID: FocusState<Entry.ID?>.Binding

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.contentView.postsBoundsChangedNotifications = true

        let textView = EntryTextView()
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.typingAttributes = defaultTypingAttributes()
        textView.textContainerInset = .zero
        textView.minSize = NSSize(width: 0, height: 22)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.delegate = context.coordinator
        EntrySelectionCoordinator.shared.register(textView)

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        context.coordinator.apply(body: body, richTextData: richTextData)
        context.coordinator.updateHeight()

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self

        if focusedEntryID.wrappedValue == entryID, textView.window?.firstResponder !== textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        guard !context.coordinator.isEditing else { return }
        if textView.string != body {
            context.coordinator.apply(body: body, richTextData: richTextData)
        } else {
            context.coordinator.applyReadableTextColor()
        }
        context.coordinator.updateHeight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEntryEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var isEditing = false

        init(parent: RichTextEntryEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                EntrySelectionCoordinator.shared.focus(textView)
            }
            parent.focusedEntryID.wrappedValue = parent.entryID
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isEditing = true
            parent.body = textView.string
            parent.richTextData = rtfData(from: textView)
            updateHeight()
            isEditing = false
        }

        func apply(body: String, richTextData: Data?) {
            guard let textView else { return }
            if let richTextData,
               let attributed = try? NSAttributedString(
                data: richTextData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                let readable = NSMutableAttributedString(attributedString: attributed)
                normalizeReadableTextColor(in: readable)
                textView.textStorage?.setAttributedString(readable)
            } else {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 17), toFamily: "New York"),
                    .foregroundColor: NSColor.labelColor
                ]
                textView.textStorage?.setAttributedString(NSAttributedString(string: body, attributes: attributes))
            }
            textView.textColor = .labelColor
            textView.typingAttributes.merge(defaultTypingAttributes()) { current, _ in current }
            updateHeight()
        }

        func applyReadableTextColor() {
            guard let storage = textView?.textStorage else { return }
            normalizeReadableTextColor(in: storage)
        }

        private func rtfData(from textView: NSTextView) -> Data? {
            guard let storage = textView.textStorage else { return nil }
            let range = NSRange(location: 0, length: storage.length)
            return try? storage.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        }

        func updateHeight() {
            guard
                let textView,
                let layoutManager = textView.layoutManager,
                let textContainer = textView.textContainer
            else { return }

            let availableWidth = scrollView?.contentSize.width ?? textView.bounds.width
            if availableWidth > 0 {
                textContainer.containerSize = NSSize(width: availableWidth, height: CGFloat.greatestFiniteMagnitude)
            }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let measuredHeight = max(22, ceil(usedRect.height + textView.textContainerInset.height * 2))

            if abs(parent.height - measuredHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.height = measuredHeight
                }
            }

            textView.frame.size.height = measuredHeight
        }
    }
}

private func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
    [
        .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 17), toFamily: "New York"),
        .foregroundColor: NSColor.labelColor
    ]
}

private func normalizeReadableTextColor(in attributedString: NSMutableAttributedString) {
    let fullRange = NSRange(location: 0, length: attributedString.length)
    guard fullRange.length > 0 else { return }
    attributedString.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)
}
