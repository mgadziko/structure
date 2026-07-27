import AppKit
import SwiftUI

struct EntryEditor: View {
    let entry: Entry
    @Binding var text: String
    @Binding var richTextData: Data?
    let columnsBeforeEntry: [EntryColumn]
    let columnsAfterEntry: [EntryColumn]
    let columnValue: (Entry.ID, EntryColumn.ID) -> String
    let saveColumnValueDraft: (Entry.ID, EntryColumn.ID, String) -> Void
    let updateColumnValue: (Entry.ID, EntryColumn.ID, String) -> Void
    let requestEntryVisibility: (Entry.ID) -> Void
    var focusedEntryID: FocusState<Entry.ID?>.Binding
    @State private var editorHeight: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(entry.displayDate)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: EntryRowLayout.createdColumnWidth, alignment: .leading)
                .padding(.top, 8)

            ForEach(columnsBeforeEntry) { column in
                UndefinedColumnCell(
                    value: columnValue(entry.id, column.id),
                    columnTitle: column.title,
                    width: column.width,
                    saveDraft: { value in
                        saveColumnValueDraft(entry.id, column.id, value)
                    },
                    commit: { value in
                        updateColumnValue(entry.id, column.id, value)
                    },
                    onFocus: {
                        requestEntryVisibility(entry.id)
                    }
                )
            }

            columnCreationSpacer()

            VStack(alignment: .leading, spacing: 5) {
                RichTextEntryEditor(
                    entryID: entry.id,
                    body: $text,
                    richTextData: $richTextData,
                    height: $editorHeight,
                    focusedEntryID: focusedEntryID
                )
                    .frame(height: editorHeight)
                    .accessibilityLabel("Entry created \(entry.displayDate)")
            }
            .frame(width: EntryRowLayout.entryColumnWidth, alignment: .leading)

            columnCreationSpacer()

            ForEach(columnsAfterEntry) { column in
                UndefinedColumnCell(
                    value: columnValue(entry.id, column.id),
                    columnTitle: column.title,
                    width: column.width,
                    saveDraft: { value in
                        saveColumnValueDraft(entry.id, column.id, value)
                    },
                    commit: { value in
                        updateColumnValue(entry.id, column.id, value)
                    },
                    onFocus: {
                        requestEntryVisibility(entry.id)
                    }
                )
            }
        }
    }
}

enum EntryRowLayout {
    static let horizontalPadding: CGFloat = 38
    static let createdColumnWidth: CGFloat = 150
    static let columnCreationControlWidth: CGFloat = 18
    static let defaultUndefinedColumnWidth: Double = 120
    static let minimumUndefinedColumnWidth: Double = 80
    static let maximumUndefinedColumnWidth: Double = 420
    static let entryColumnWidth: CGFloat = 300
}

private struct UndefinedColumnCell: View {
    let value: String
    let columnTitle: String
    let width: Double
    let saveDraft: (String) -> Void
    let commit: (String) -> Void
    let onFocus: () -> Void
    @State private var draft = ""
    @State private var cellHeight: CGFloat = 24

    var body: some View {
        ExpandingColumnTextEditor(
            text: $draft,
            height: $cellHeight,
            width: width,
            placeholder: "...",
            onDraftChange: saveDraft,
            onCommit: commit,
            onFocus: onFocus
        )
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
            .accessibilityLabel("\(columnTitle) value")
            .frame(width: width, height: cellHeight, alignment: .topLeading)
            .onAppear {
                draft = value
            }
            .onChange(of: value) { newValue in
                draft = newValue
            }
    }
}

private struct ExpandingColumnTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    let width: Double
    let placeholder: String
    let onDraftChange: (String) -> Void
    let onCommit: (String) -> Void
    let onFocus: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textColor = .labelColor
        textView.textContainerInset = NSSize(width: 6, height: 3)
        textView.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: 24
        )
        textView.minSize = NSSize(width: width, height: 24)
        textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = []
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.containerSize = NSSize(
            width: parentTextWidth(width),
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.delegate = context.coordinator

        context.coordinator.textView = textView
        context.coordinator.placeholderString = placeholder
        context.coordinator.applyText(text)
        context.coordinator.updateHeight()

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        context.coordinator.applyWidth(width)
        if !context.coordinator.isEditing, textView.string != text {
            context.coordinator.applyText(text)
        }
        context.coordinator.updateHeight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExpandingColumnTextEditor
        weak var textView: NSTextView?
        var placeholderString = "..."
        var isEditing = false

        init(parent: ExpandingColumnTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            isEditing = true
            parent.onFocus()
            if textView?.string == placeholderString {
                textView?.string = ""
                textView?.textColor = .labelColor
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.onDraftChange(textView.string)
            updateHeight()
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            parent.onCommit(parent.text)
            applyText(parent.text)
        }

        func applyText(_ text: String) {
            guard let textView else { return }
            if text.isEmpty, !isEditing {
                textView.string = placeholderString
                textView.textColor = .tertiaryLabelColor
            } else {
                textView.string = text
                textView.textColor = .labelColor
            }
            updateHeight()
        }

        func applyWidth(_ width: Double) {
            guard let textView else { return }
            textView.minSize = NSSize(width: width, height: 24)
            textView.maxSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.containerSize = NSSize(
                width: parentTextWidth(width),
                height: CGFloat.greatestFiniteMagnitude
            )
            updateHeight()
        }

        func updateHeight() {
            guard
                let textView,
                let layoutManager = textView.layoutManager,
                let textContainer = textView.textContainer
            else { return }

            textContainer.containerSize = NSSize(
                width: parentTextWidth(parent.width),
                height: CGFloat.greatestFiniteMagnitude
            )
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let measuredHeight = max(24, ceil(usedRect.height + textView.textContainerInset.height * 2))

            if abs(parent.height - measuredHeight) > 0.5 {
                DispatchQueue.main.async {
                    self.parent.height = measuredHeight
                }
            }
            textView.frame = NSRect(
                x: 0,
                y: 0,
                width: parent.width,
                height: measuredHeight
            )
        }
    }
}

private func parentTextWidth(_ width: Double) -> CGFloat {
    max(24, CGFloat(width) - 12)
}

private func columnCreationSpacer() -> some View {
    Color.clear
        .frame(width: EntryRowLayout.columnCreationControlWidth, height: 18)
        .accessibilityHidden(true)
}
