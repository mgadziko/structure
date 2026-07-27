import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct EntryColumnHeader: View {
    let sort: EntrySort
    let sortBy: (EntrySortColumn) -> Void
    let columnsBeforeEntry: [EntryColumn]
    let columnsAfterEntry: [EntryColumn]
    let addColumn: (String, EntryColumnPlacement) -> Void
    let moveColumn: (EntryColumn.ID, EntryColumn.ID) -> Void
    let resizeColumn: (EntryColumn.ID, Double) -> Void
    @State private var draftColumnPlacement: EntryColumnPlacement?
    @State private var draftColumnTitle = ""
    @State private var draggedColumnID: EntryColumn.ID?
    @FocusState private var draftIsFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            SortHeaderButton(
                title: "Created",
                column: .created,
                sort: sort,
                action: sortBy
            )
            .frame(width: EntryRowLayout.createdColumnWidth, alignment: .leading)

            ForEach(columnsBeforeEntry) { column in
                UndefinedColumnHeader(
                    column: column,
                    sort: sort,
                    action: sortBy,
                    draggedColumnID: $draggedColumnID,
                    moveColumn: moveColumn,
                    resizeColumn: resizeColumn
                )
            }

            columnCreationControl(for: .beforeEntry)

            SortHeaderButton(
                title: "Entry",
                column: .body,
                sort: sort,
                action: sortBy
            )
            .frame(width: EntryRowLayout.entryColumnWidth, alignment: .leading)

            columnCreationControl(for: .afterEntry)

            ForEach(columnsAfterEntry) { column in
                UndefinedColumnHeader(
                    column: column,
                    sort: sort,
                    action: sortBy,
                    draggedColumnID: $draggedColumnID,
                    moveColumn: moveColumn,
                    resizeColumn: resizeColumn
                )
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, EntryRowLayout.horizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Color(nsColor: .textBackgroundColor))
    }

    @ViewBuilder
    private func columnCreationControl(for placement: EntryColumnPlacement) -> some View {
        if draftColumnPlacement == placement {
            TextField("Column", text: $draftColumnTitle)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: EntryRowLayout.defaultUndefinedColumnWidth, alignment: .leading)
                .focused($draftIsFocused)
                .onSubmit {
                    commitDraftColumn()
                }
                .onAppear {
                    draftIsFocused = true
                }
        } else {
            Button {
                draftColumnPlacement = placement
                draftColumnTitle = ""
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: EntryRowLayout.columnCreationControlWidth, height: 18)
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
}

private struct UndefinedColumnHeader: View {
    let column: EntryColumn
    let sort: EntrySort
    let action: (EntrySortColumn) -> Void
    @Binding var draggedColumnID: EntryColumn.ID?
    let moveColumn: (EntryColumn.ID, EntryColumn.ID) -> Void
    let resizeColumn: (EntryColumn.ID, Double) -> Void
    @State private var dragStartWidth: Double?
    @State private var previewWidth: Double?

    private var displayWidth: Double {
        previewWidth ?? column.width
    }

    var body: some View {
        HStack(spacing: 0) {
            SortHeaderButton(
                title: column.title,
                column: .userColumn(column.id),
                sort: sort,
                action: action
            )
            .frame(maxWidth: .infinity, alignment: .leading)

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
                            previewWidth = clampedColumnWidth(baseWidth + value.translation.width)
                        }
                        .onEnded { value in
                            let baseWidth = dragStartWidth ?? column.width
                            resizeColumn(column.id, baseWidth + value.translation.width)
                            previewWidth = nil
                            dragStartWidth = nil
                        }
                )
                .help("Drag to resize column")
        }
        .frame(width: displayWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onDrag {
            draggedColumnID = column.id
            return NSItemProvider(object: column.id as NSString)
        }
        .onDrop(
            of: [UTType.text],
            delegate: EntryColumnDropDelegate(
                targetColumnID: column.id,
                draggedColumnID: $draggedColumnID,
                moveColumn: moveColumn
            )
        )
        .help("Drag heading to rearrange; drag right edge to resize")
    }
}

private func clampedColumnWidth(_ width: Double) -> Double {
    min(max(width, EntryRowLayout.minimumUndefinedColumnWidth), EntryRowLayout.maximumUndefinedColumnWidth)
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
    @Binding var draggedColumnID: EntryColumn.ID?
    let moveColumn: (EntryColumn.ID, EntryColumn.ID) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedColumnID, draggedColumnID != targetColumnID else { return }
        moveColumn(draggedColumnID, targetColumnID)
        self.draggedColumnID = targetColumnID
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedColumnID = nil
        return true
    }
}

private struct SortHeaderButton: View {
    let title: String
    let column: EntrySortColumn
    let sort: EntrySort
    let action: (EntrySortColumn) -> Void

    var body: some View {
        Button {
            action(column)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                if sort.column == column {
                    Image(systemName: sort.direction == .ascending ? "arrow.up" : "arrow.down")
                        .font(.system(size: 10, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
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
