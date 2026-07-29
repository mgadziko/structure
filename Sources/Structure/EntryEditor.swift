import AppKit
import SwiftUI

struct EntryEditor: View {
    let entry: Entry
    let rowNumber: Int
    @Binding var text: String
    @Binding var richTextData: Data?
    let showCreatedColumn: Bool
    let columnsBeforeEntry: [EntryColumn]
    let columnsAfterEntry: [EntryColumn]
    let columnValue: (Entry.ID, EntryColumn.ID) -> EntryColumnValue
    let columnAutocompleteSource: (Entry.ID, EntryColumn.ID) -> String
    let saveColumnValueDraft: (Entry.ID, EntryColumn.ID, EntryColumnValue) -> Void
    let updateColumnValue: (Entry.ID, EntryColumn.ID, EntryColumnValue) -> Void
    let beginEntryEditing: (Entry.ID) -> Void
    let endEntryEditing: (Entry.ID) -> Void
    let beginColumnEditing: (Entry.ID, EntryColumn.ID) -> Void
    let endColumnEditing: (Entry.ID, EntryColumn.ID) -> Void
    var focusedEntryID: FocusState<Entry.ID?>.Binding
    @State private var editorHeight: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text("\(rowNumber)")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: EntryRowLayout.rowNumberColumnWidth, alignment: .trailing)
                .padding(.top, 8)

            if showCreatedColumn {
                Text(entry.displayDate)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: EntryRowLayout.createdColumnWidth, alignment: .leading)
                    .padding(.top, 8)
            }

            ForEach(columnsBeforeEntry) { column in
                UndefinedColumnCell(
                    value: columnValue(entry.id, column.id),
                    entryText: text,
                    columnAutocompleteText: columnAutocompleteSource(entry.id, column.id),
                    entryID: entry.id,
                    columnID: column.id,
                    columnTitle: column.title,
                    width: column.width,
                    rowHeight: editorHeight,
                    saveDraft: { value in
                        saveColumnValueDraft(entry.id, column.id, value)
                    },
                    commit: { value in
                        updateColumnValue(entry.id, column.id, value)
                    },
                    beginEditing: {
                        beginColumnEditing(entry.id, column.id)
                    },
                    endEditing: {
                        endColumnEditing(entry.id, column.id)
                    }
                )
            }

            columnCreationSpacer()

            VStack(alignment: .leading, spacing: 5) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Type here")
                            .font(.system(size: 17))
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }

                    RichTextEntryEditor(
                    entryID: entry.id,
                    body: $text,
                    richTextData: $richTextData,
                    height: $editorHeight,
                    focusedEntryID: focusedEntryID,
                    onBeginEditing: {
                        beginEntryEditing(entry.id)
                    },
                    onEndEditing: {
                        endEntryEditing(entry.id)
                    }
                )
                    .frame(height: editorHeight)
                    .accessibilityLabel("Entry created \(entry.displayDate)")
                }
            }
            .frame(width: EntryRowLayout.entryColumnWidth, alignment: .leading)

            columnCreationSpacer()

            ForEach(columnsAfterEntry) { column in
                UndefinedColumnCell(
                    value: columnValue(entry.id, column.id),
                    entryText: text,
                    columnAutocompleteText: columnAutocompleteSource(entry.id, column.id),
                    entryID: entry.id,
                    columnID: column.id,
                    columnTitle: column.title,
                    width: column.width,
                    rowHeight: editorHeight,
                    saveDraft: { value in
                        saveColumnValueDraft(entry.id, column.id, value)
                    },
                    commit: { value in
                        updateColumnValue(entry.id, column.id, value)
                    },
                    beginEditing: {
                        beginColumnEditing(entry.id, column.id)
                    },
                    endEditing: {
                        endColumnEditing(entry.id, column.id)
                    }
                )
            }
        }
        .onAppear {
            EntrySelectionCoordinator.shared.updateCellOrder(
                entryID: entry.id,
                columnsBeforeEntry: columnsBeforeEntry,
                columnsAfterEntry: columnsAfterEntry
            )
        }
        .onChange(of: columnsBeforeEntry) { _ in
            EntrySelectionCoordinator.shared.updateCellOrder(
                entryID: entry.id,
                columnsBeforeEntry: columnsBeforeEntry,
                columnsAfterEntry: columnsAfterEntry
            )
        }
        .onChange(of: columnsAfterEntry) { _ in
            EntrySelectionCoordinator.shared.updateCellOrder(
                entryID: entry.id,
                columnsBeforeEntry: columnsBeforeEntry,
                columnsAfterEntry: columnsAfterEntry
            )
        }
    }
}

enum EntryRowLayout {
    static let horizontalPadding: CGFloat = 38
    static let rowNumberColumnWidth: CGFloat = 34
    static let createdColumnWidth: CGFloat = 150
    static let columnCreationControlWidth: CGFloat = 18
    static let defaultUndefinedColumnWidth: Double = 120
    static let minimumUndefinedColumnWidth: Double = 80
    static let maximumUndefinedColumnWidth: Double = 420
    static let entryColumnWidth: CGFloat = 300
}

private struct UndefinedColumnCell: View {
    let value: EntryColumnValue
    let entryText: String
    let columnAutocompleteText: String
    let entryID: Entry.ID
    let columnID: EntryColumn.ID
    let columnTitle: String
    let width: Double
    let rowHeight: CGFloat
    let saveDraft: (EntryColumnValue) -> Void
    let commit: (EntryColumnValue) -> Void
    let beginEditing: () -> Void
    let endEditing: () -> Void
    @State private var draft = ""
    @State private var draftRichTextData: Data?
    @State private var cellHeight: CGFloat = 24

    private var displayHeight: CGFloat {
        max(cellHeight, rowHeight)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ExpandingColumnTextEditor(
                text: $draft,
                richTextData: $draftRichTextData,
                autocompleteSourceText: autocompleteSourceText,
                entryID: entryID,
                columnID: columnID,
                height: $cellHeight,
                width: width,
                displayHeight: displayHeight,
                onDraftChange: saveDraft,
                onCommit: commit,
                onBeginEditing: beginEditing,
                onEndEditing: endEditing
            )

            if draft.isEmpty {
                Text("...")
                    .font(.custom("New York", size: 17))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 6)
                    .padding(.top, 3)
                    .allowsHitTesting(false)
            }
        }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
            .accessibilityLabel("\(columnTitle) value")
            .frame(width: width, height: displayHeight, alignment: .topLeading)
            .onAppear {
                draft = value.text
                draftRichTextData = value.richTextData
            }
            .onChange(of: value) { newValue in
                draft = newValue.text
                draftRichTextData = newValue.richTextData
            }
    }

    private var autocompleteSourceText: String {
        [entryText, columnAutocompleteText]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

private struct ExpandingColumnTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var richTextData: Data?
    let autocompleteSourceText: String
    let entryID: Entry.ID
    let columnID: EntryColumn.ID
    @Binding var height: CGFloat
    let width: Double
    let displayHeight: CGFloat
    let onDraftChange: (EntryColumnValue) -> Void
    let onCommit: (EntryColumnValue) -> Void
    let onBeginEditing: () -> Void
    let onEndEditing: () -> Void

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = ColumnCellScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = ColumnCellTextView()
        textView.autocompleteSourceText = autocompleteSourceText
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textColor = .labelColor
        textView.typingAttributes = columnTypingAttributes()
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
        EntrySelectionCoordinator.shared.registerColumnTextView(textView, entryID: entryID, columnID: columnID)

        context.coordinator.textView = textView
        context.coordinator.apply(text: text, richTextData: richTextData)
        context.coordinator.updateHeight()

        scrollView.documentView = textView
        scrollView.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        context.coordinator.parent = self
        (textView as? ColumnCellTextView)?.autocompleteSourceText = autocompleteSourceText
        context.coordinator.applyWidth(width)
        if !context.coordinator.isEditing,
           textView.string != text || context.coordinator.appliedRichTextData != richTextData {
            context.coordinator.apply(text: text, richTextData: richTextData)
        }
        context.coordinator.updateHeight()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: ExpandingColumnTextEditor
        weak var textView: NSTextView?
        var isEditing = false
        var appliedRichTextData: Data?

        init(parent: ExpandingColumnTextEditor) {
            self.parent = parent
        }

        func textDidBeginEditing(_ notification: Notification) {
            if let textView = notification.object as? NSTextView {
                EntrySelectionCoordinator.shared.focus(textView)
            }
            isEditing = true
            parent.onBeginEditing()
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            parent.richTextData = rtfData(from: textView)
            parent.onDraftChange(EntryColumnValue(text: textView.string, richTextData: parent.richTextData))
            updateHeight()
            EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: textView)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            (textView as? ColumnCellTextView)?.updateGhostCompletion()
            EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            isEditing = false
            parent.onCommit(EntryColumnValue(text: parent.text, richTextData: parent.richTextData))
            parent.onEndEditing()
            apply(text: parent.text, richTextData: parent.richTextData)
        }

        func apply(text: String, richTextData: Data?) {
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
                textView.textStorage?.setAttributedString(NSAttributedString(string: text, attributes: columnTypingAttributes()))
            }
            appliedRichTextData = richTextData
            textView.textColor = .labelColor
            textView.typingAttributes.merge(columnTypingAttributes()) { current, _ in current }
            updateHeight()
        }

        private func rtfData(from textView: NSTextView) -> Data? {
            guard let storage = textView.textStorage else { return nil }
            let range = NSRange(location: 0, length: storage.length)
            return try? storage.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
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
                height: max(measuredHeight, parent.displayHeight)
            )
        }
    }
}

private final class ColumnCellScrollView: NSScrollView {
    weak var textView: NSTextView?

    override func mouseDown(with event: NSEvent) {
        if let textView {
            window?.makeFirstResponder(textView)
            EntrySelectionCoordinator.shared.focus(textView)
        }
        super.mouseDown(with: event)
        if let textView {
            DispatchQueue.main.async {
                EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: textView)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if let textView {
            EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: textView)
        }
    }
}

private final class ColumnCellTextView: NSTextView {
    var autocompleteSourceText = "" {
        didSet {
            updateGhostCompletion()
        }
    }

    private var ghostSuffix = ""

    deinit {
        EntrySelectionCoordinator.shared.unregister(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48,
           !event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.shift),
           acceptGhostCompletion() {
            EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
            return
        }

        if handleTabNavigation(in: self, event: event) {
            return
        }

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "a" {
            EntrySelectionCoordinator.shared.handleSelectAll(in: self)
            return
        }

        super.keyDown(with: event)
        updateGhostCompletion()
        EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawGhostCompletion()
    }

    override func mouseDown(with event: NSEvent) {
        EntrySelectionCoordinator.shared.focus(self)
        super.mouseDown(with: event)
        DispatchQueue.main.async {
            self.updateGhostCompletion()
            EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        updateGhostCompletion()
        EntrySelectionCoordinator.shared.notifyTextSelectionChanged(in: self)
    }

    func updateGhostCompletion() {
        let newSuffix = completionSuffix()
        if ghostSuffix != newSuffix {
            ghostSuffix = newSuffix
            needsDisplay = true
        }
    }

    private func acceptGhostCompletion() -> Bool {
        guard !ghostSuffix.isEmpty,
              selectedRange().length == 0
        else { return false }

        let suffix = ghostSuffix
        ghostSuffix = ""
        insertText(suffix, replacementRange: selectedRange())
        updateGhostCompletion()
        return true
    }

    private func completionSuffix() -> String {
        guard selectedRange().length == 0,
              let fragment = wordFragmentBeforeInsertionPoint(),
              !fragment.isEmpty
        else { return "" }

        let lowercasedFragment = fragment.lowercased()
        for candidate in autocompleteCandidates(from: autocompleteSourceText) {
            let lowercasedCandidate = candidate.lowercased()
            if lowercasedCandidate.hasPrefix(lowercasedFragment),
               lowercasedCandidate != lowercasedFragment {
                return String(candidate.dropFirst(fragment.count))
            }
        }

        return ""
    }

    private func wordFragmentBeforeInsertionPoint() -> String? {
        let nsString = string as NSString
        let location = selectedRange().location
        guard location > 0, location <= nsString.length else { return nil }

        var start = location
        while start > 0 {
            let previousIndex = start - 1
            let scalar = nsString.character(at: previousIndex)
            guard isAutocompleteWordCharacter(scalar) else { break }
            start = previousIndex
        }

        guard start < location else { return nil }
        return nsString.substring(with: NSRange(location: start, length: location - start))
    }

    private func drawGhostCompletion() {
        guard !ghostSuffix.isEmpty,
              selectedRange().length == 0,
              let window
        else { return }

        let selectedRange = selectedRange()
        guard selectedRange.location <= (string as NSString).length else { return }

        var actualRange = NSRange(location: 0, length: 0)
        let screenRect = firstRect(forCharacterRange: selectedRange, actualRange: &actualRange)
        guard screenRect != .zero else { return }

        let windowRect = window.convertFromScreen(screenRect)
        let localRect = convert(windowRect, from: nil)
        let font = typingAttributes[.font] as? NSFont ?? self.font ?? NSFont.systemFont(ofSize: 17)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        (ghostSuffix as NSString).draw(
            at: NSPoint(x: localRect.minX, y: localRect.minY),
            withAttributes: attributes
        )
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

private func columnTypingAttributes() -> [NSAttributedString.Key: Any] {
    defaultTypingAttributes()
}

private func autocompleteCandidates(from source: String) -> [String] {
    let pattern = #"\p{L}[\p{L}\p{N}'’_-]*|\p{N}[\p{L}\p{N}'’_-]*"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

    let nsSource = source as NSString
    let matches = regex.matches(in: source, range: NSRange(location: 0, length: nsSource.length))
    var seen: Set<String> = []
    var candidates: [String] = []

    for match in matches {
        let candidate = nsSource.substring(with: match.range)
        let key = candidate.lowercased()
        if seen.insert(key).inserted {
            candidates.append(candidate)
        }
    }

    return candidates
}

private func isAutocompleteWordCharacter(_ scalar: unichar) -> Bool {
    let allowedPunctuation = CharacterSet(charactersIn: "'’_-")
    guard let unicodeScalar = UnicodeScalar(Int(scalar)) else { return false }
    return CharacterSet.alphanumerics.contains(unicodeScalar)
        || allowedPunctuation.contains(unicodeScalar)
}
