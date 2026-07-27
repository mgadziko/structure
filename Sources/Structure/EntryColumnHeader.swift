import SwiftUI

struct EntryColumnHeader: View {
    let sort: EntrySort
    let sortBy: (EntrySortColumn) -> Void
    let columnsBeforeEntry: [EntryColumn]
    let columnsAfterEntry: [EntryColumn]
    let addColumn: (String, EntryColumnPlacement) -> Void
    @State private var draftColumnPlacement: EntryColumnPlacement?
    @State private var draftColumnTitle = ""
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
                UndefinedColumnHeader(title: column.title)
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
                UndefinedColumnHeader(title: column.title)
            }
            Spacer()
        }
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
                .frame(width: EntryRowLayout.undefinedColumnWidth, alignment: .leading)
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
                    .frame(width: 18, height: 18)
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
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.blue)
            .frame(width: EntryRowLayout.undefinedColumnWidth, alignment: .leading)
            .help("Undefined column")
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
