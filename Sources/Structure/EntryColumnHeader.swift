import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EntryColumnHeader: View {
    let sort: EntrySort
    let sortBy: (EntrySortColumn) -> Void
    let showCreatedColumn: Bool
    let columnsBeforeEntry: [EntryColumn]
    let columnsAfterEntry: [EntryColumn]
    let criteriaColumnIDs: Set<EntryColumn.ID>
    let viewScale: CGFloat
    let availableColumnNames: [String]
    let addColumn: (String, EntryColumnPlacement) -> Void
    let moveColumn: (EntryColumn.ID, EntryColumn.ID, ColumnDropPlacement) -> Void
    let renameColumn: (EntryColumn.ID, String) -> Void
    let updateColumnDefinition: (EntryColumn.ID, EntryColumnDefinition) -> Void
    let resizeColumn: (EntryColumn.ID, Double) -> Void
    let beginHeaderEditing: () -> Void
    @State private var draftColumnPlacement: EntryColumnPlacement?
    @State private var draftColumnTitle = ""
    @State private var draggedColumnID: EntryColumn.ID?
    @State private var inspectedColumn: EntryColumn?
    @FocusState private var draftIsFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: scaled(18)) {
            Text("#")
                .font(.system(size: scaled(13), weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: scaled(EntryRowLayout.rowNumberColumnWidth), alignment: .trailing)
                .accessibilityLabel("Row number")

            if showCreatedColumn {
                SortHeaderButton(
                    title: "Created",
                    column: .created,
                    sort: sort,
                    viewScale: viewScale,
                    action: { column in
                        beginHeaderEditing()
                        sortBy(column)
                    }
                )
                .frame(width: scaled(EntryRowLayout.createdColumnWidth), alignment: .leading)
            }

            ForEach(columnsBeforeEntry) { column in
                UndefinedColumnHeader(
                    column: column,
                    sort: sort,
                    action: { column in
                        beginHeaderEditing()
                        sortBy(column)
                    },
                    renameColumn: renameColumn,
                    inspectColumn: { column in
                        beginHeaderEditing()
                        inspectedColumn = column
                    },
                    beginHeaderEditing: beginHeaderEditing,
                    draggedColumnID: $draggedColumnID,
                    moveColumn: moveColumn,
                    resizeColumn: resizeColumn,
                    isCriteriaColumn: criteriaColumnIDs.contains(column.id),
                    viewScale: viewScale
                )
            }

            columnCreationControl(for: .beforeEntry)

            SortHeaderButton(
                title: "Entry",
                column: .body,
                sort: sort,
                viewScale: viewScale,
                action: { column in
                    beginHeaderEditing()
                    sortBy(column)
                }
            )
            .frame(width: scaled(EntryRowLayout.entryColumnWidth), alignment: .leading)

            columnCreationControl(for: .afterEntry)

            ForEach(columnsAfterEntry) { column in
                UndefinedColumnHeader(
                    column: column,
                    sort: sort,
                    action: { column in
                        beginHeaderEditing()
                        sortBy(column)
                    },
                    renameColumn: renameColumn,
                    inspectColumn: { column in
                        beginHeaderEditing()
                        inspectedColumn = column
                    },
                    beginHeaderEditing: beginHeaderEditing,
                    draggedColumnID: $draggedColumnID,
                    moveColumn: moveColumn,
                    resizeColumn: resizeColumn,
                    isCriteriaColumn: criteriaColumnIDs.contains(column.id),
                    viewScale: viewScale
                )
            }
            if let lastColumn = columnsAfterEntry.last {
                trailingColumnDropZone(after: lastColumn)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, scaled(EntryRowLayout.horizontalPadding))
        .padding(.top, scaled(20))
        .padding(.bottom, scaled(8))
        .background(Color(nsColor: .textBackgroundColor))
        .sheet(item: $inspectedColumn) { column in
            ColumnDefinitionInspector(
                column: column,
                updateColumnDefinition: { definition in
                    updateColumnDefinition(column.id, definition)
                    inspectedColumn = nil
                },
                cancel: {
                    inspectedColumn = nil
                }
            )
        }
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        value * viewScale
    }

    @ViewBuilder
    private func columnCreationControl(for placement: EntryColumnPlacement) -> some View {
        if draftColumnPlacement == placement {
            ColumnNameComboBox(
                values: availableColumnNames,
                text: $draftColumnTitle,
                onCommit: commitDraftColumn
            )
            .frame(width: EntryRowLayout.defaultUndefinedColumnWidth * Double(viewScale), height: scaled(24), alignment: .leading)
            .focused($draftIsFocused)
            .onAppear {
                DispatchQueue.main.async {
                    draftIsFocused = true
                }
            }
        } else {
            Button {
                beginHeaderEditing()
                draftColumnPlacement = placement
                draftColumnTitle = ""
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: scaled(10), weight: .semibold))
                    .frame(width: scaled(EntryRowLayout.columnCreationControlWidth), height: scaled(18))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)
            .accessibilityLabel(placement == .beforeEntry ? "Add column before Entry" : "Add column after Entry")
        }
    }

    private func commitDraftColumn() {
        guard let draftColumnPlacement else { return }
        addColumn(draftColumnTitle, draftColumnPlacement)
        self.draftColumnPlacement = nil
        draftColumnTitle = ""
    }

    private func trailingColumnDropZone(after column: EntryColumn) -> some View {
        Color.clear
            .frame(width: 72, height: 28)
            .contentShape(Rectangle())
            .onDrop(
                of: [UTType.text],
                delegate: EntryColumnDropDelegate(
                    targetColumnID: column.id,
                    targetWidth: 1,
                    forcedPlacement: .after,
                    draggedColumnID: $draggedColumnID,
                    moveColumn: moveColumn
                )
            )
            .help("Drop here to move column to the far right")
    }
}

private struct ColumnNameComboBox: NSViewRepresentable {
    let values: [String]
    @Binding var text: String
    let onCommit: () -> Void

    func makeNSView(context: Context) -> NSComboBox {
        let comboBox = NSComboBox()
        comboBox.usesDataSource = false
        comboBox.addItems(withObjectValues: values)
        comboBox.completes = true
        comboBox.numberOfVisibleItems = min(max(values.count, 1), 12)
        comboBox.stringValue = text
        comboBox.delegate = context.coordinator
        return comboBox
    }

    func updateNSView(_ comboBox: NSComboBox, context: Context) {
        let existingItems = (0..<comboBox.numberOfItems).compactMap { comboBox.itemObjectValue(at: $0) as? String }
        if existingItems != values {
            comboBox.removeAllItems()
            comboBox.addItems(withObjectValues: values)
            comboBox.numberOfVisibleItems = min(max(values.count, 1), 12)
        }
        if comboBox.stringValue != text {
            comboBox.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    final class Coordinator: NSObject, NSComboBoxDelegate {
        @Binding var text: String
        let onCommit: () -> Void

        init(text: Binding<String>, onCommit: @escaping () -> Void) {
            _text = text
            self.onCommit = onCommit
        }

        func comboBoxSelectionDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            if comboBox.indexOfSelectedItem >= 0,
               let selectedValue = comboBox.itemObjectValue(at: comboBox.indexOfSelectedItem) as? String {
                text = selectedValue
                comboBox.stringValue = selectedValue
            } else {
                text = comboBox.stringValue
            }
            onCommit()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            text = comboBox.stringValue
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let comboBox = notification.object as? NSComboBox else { return }
            text = comboBox.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                text = control.stringValue
                onCommit()
                return true
            }
            return false
        }
    }
}

private struct UndefinedColumnHeader: View {
    let column: EntryColumn
    let sort: EntrySort
    let action: (EntrySortColumn) -> Void
    let renameColumn: (EntryColumn.ID, String) -> Void
    let inspectColumn: (EntryColumn) -> Void
    let beginHeaderEditing: () -> Void
    @Binding var draggedColumnID: EntryColumn.ID?
    let moveColumn: (EntryColumn.ID, EntryColumn.ID, ColumnDropPlacement) -> Void
    let resizeColumn: (EntryColumn.ID, Double) -> Void
    let isCriteriaColumn: Bool
    let viewScale: CGFloat
    @State private var dragStartWidth: Double?
    @State private var previewWidth: Double?
    @State private var isEditingTitle = false
    @State private var titleDraft = ""
    @FocusState private var titleIsFocused: Bool

    private var displayWidth: Double {
        previewWidth ?? column.width
    }

    var body: some View {
        HStack(spacing: 0) {
            titleControl
                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)

            ZStack {
                Color.clear
                    .frame(width: 20, height: 26)

                Rectangle()
                    .fill(Color(nsColor: .separatorColor).opacity(0.9))
                    .frame(width: 3, height: 18)
            }
                .resizeCursor()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let baseWidth = dragStartWidth ?? column.width
                            dragStartWidth = baseWidth
                            previewWidth = clampedColumnWidth(baseWidth + value.translation.width / Double(viewScale))
                        }
                        .onEnded { value in
                            let baseWidth = dragStartWidth ?? column.width
                            resizeColumn(column.id, baseWidth + value.translation.width / Double(viewScale))
                            previewWidth = nil
                            dragStartWidth = nil
                        }
                )
                .help("Drag to resize column")
        }
        .frame(width: displayWidth, alignment: .leading)
        .scaleEffect(viewScale, anchor: .topLeading)
        .frame(width: displayWidth * Double(viewScale), alignment: .leading)
        .contentShape(Rectangle())
        .onDrag {
            draggedColumnID = column.id
            return NSItemProvider(object: column.id as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: EntryColumnDropDelegate(
                targetColumnID: column.id,
                targetWidth: displayWidth,
                draggedColumnID: $draggedColumnID,
                moveColumn: moveColumn
            )
        )
        .onChange(of: column.title) { newTitle in
            if !isEditingTitle {
                titleDraft = newTitle
            }
        }
        .contextMenu {
            Button("Column Info...") {
                inspectColumn(column)
            }
        }
        .help("Click to sort; double-click heading to rename; drag heading to rearrange; drag right edge to resize")
    }

    @ViewBuilder
    private var titleControl: some View {
        if isEditingTitle {
            TextField("Column", text: $titleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .focused($titleIsFocused)
                .onSubmit {
                    commitTitle()
                }
                .onAppear {
                    titleDraft = column.title
                    DispatchQueue.main.async {
                        titleIsFocused = true
                    }
                }
                .onChange(of: titleIsFocused) { focused in
                    if !focused {
                        commitTitle()
                    }
                }
        } else {
            SortHeaderButton(
                title: column.title,
                column: .userColumn(column.id),
                definition: column.definition,
                sort: sort,
                viewScale: viewScale,
                isCriteriaColumn: isCriteriaColumn,
                action: action,
                definitionAction: {
                    beginHeaderEditing()
                    inspectColumn(column)
                }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        beginHeaderEditing()
                        titleDraft = column.title
                        isEditingTitle = true
                    }
            )
        }
    }

    private func commitTitle() {
        let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            renameColumn(column.id, trimmedTitle)
        } else {
            titleDraft = column.title
        }
        isEditingTitle = false
    }
}

private struct ColumnDefinitionInspector: View {
    let column: EntryColumn
    let updateColumnDefinition: (EntryColumnDefinition) -> Void
    let cancel: () -> Void
    @State private var selectedDefinition: EntryColumnDefinition

    init(
        column: EntryColumn,
        updateColumnDefinition: @escaping (EntryColumnDefinition) -> Void,
        cancel: @escaping () -> Void
    ) {
        self.column = column
        self.updateColumnDefinition = updateColumnDefinition
        self.cancel = cancel
        _selectedDefinition = State(initialValue: column.definition)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(column.title)
                    .font(.headline)
                Text("Column Definition")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker("Kind", selection: $selectedDefinition) {
                ForEach(EntryColumnDefinition.allCases) { definition in
                    Text(definition.displayName).tag(definition)
                }
            }
            .pickerStyle(.menu)

            Text(selectedDefinition.inspectorDescription)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel") {
                    cancel()
                }
                Button("Apply") {
                    updateColumnDefinition(selectedDefinition)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
    }
}

private func clampedColumnWidth(_ width: Double) -> Double {
    min(max(width, EntryRowLayout.minimumUndefinedColumnWidth), EntryRowLayout.maximumUndefinedColumnWidth)
}

private var criteriaHeaderColor: Color {
    Color(nsColor: NSColor(name: nil) { appearance in
        let bestMatch = appearance.bestMatch(from: [.darkAqua, .aqua])
        if bestMatch == .darkAqua {
            return NSColor(calibratedRed: 0.31, green: 0.92, blue: 0.45, alpha: 1.0)
        }
        return NSColor(calibratedRed: 0.0, green: 0.48, blue: 0.18, alpha: 1.0)
    })
}

private struct ResizeCursorModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.background(ResizeCursorView())
    }
}

private extension View {
    func resizeCursor() -> some View {
        modifier(ResizeCursorModifier())
    }
}

private struct ResizeCursorView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ResizeCursorNSView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }
}

private struct EntryColumnDropDelegate: DropDelegate {
    let targetColumnID: EntryColumn.ID
    let targetWidth: Double
    var forcedPlacement: ColumnDropPlacement?
    @Binding var draggedColumnID: EntryColumn.ID?
    let moveColumn: (EntryColumn.ID, EntryColumn.ID, ColumnDropPlacement) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        draggedColumnID != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedColumnID, draggedColumnID != targetColumnID else {
            self.draggedColumnID = nil
            return false
        }
        let placement: ColumnDropPlacement = forcedPlacement ?? (info.location.x < targetWidth / 2 ? .before : .after)
        moveColumn(draggedColumnID, targetColumnID, placement)
        self.draggedColumnID = nil
        return true
    }
}

private struct SortHeaderButton: View {
    let title: String
    let column: EntrySortColumn
    var definition: EntryColumnDefinition? = nil
    let sort: EntrySort
    let viewScale: CGFloat
    var isCriteriaColumn = false
    let action: (EntrySortColumn) -> Void
    var definitionAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 4) {
            Button {
                action(column)
            } label: {
                Text(title)
                if sort.column == column {
                    Image(systemName: sort.direction == .ascending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10 * viewScale, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)

            if let definition,
               let symbolName = definition.symbolName {
                if let definitionAction {
                    Button {
                        definitionAction()
                    } label: {
                        Image(systemName: symbolName)
                            .font(.system(size: 9 * viewScale, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(definition.displayName) column definition")
                    .help("Column Info: \(definition.displayName)")
                } else {
                    Image(systemName: symbolName)
                        .font(.system(size: 9 * viewScale, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(definition.displayName)
                        .help(definition.displayName)
                }
            }
        }
        .font(.system(size: 13 * viewScale, weight: .semibold))
        .foregroundStyle(isCriteriaColumn ? criteriaHeaderColor : .blue)
        .accessibilityLabel("\(title), sorted \(sortDescription)")
    }

    private var sortDescription: String {
        guard sort.column == column else {
            return "not selected"
        }

        switch sort.direction {
        case .ascending:
            return "ascending"
        case .descending:
            return "descending"
        }
    }
}
