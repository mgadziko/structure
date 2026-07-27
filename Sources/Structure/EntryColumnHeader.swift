import SwiftUI

struct EntryColumnHeader: View {
    let sort: EntrySort
    let sortBy: (EntrySortColumn) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            SortHeaderButton(
                title: "Created",
                column: .created,
                sort: sort,
                action: sortBy
            )
            .frame(width: EntryRowLayout.createdColumnWidth, alignment: .leading)

            SortHeaderButton(
                title: "Entry",
                column: .body,
                sort: sort,
                action: sortBy
            )
            Spacer()
        }
        .padding(.horizontal, 38)
        .padding(.top, 20)
        .padding(.bottom, 8)
        .background(Color(nsColor: .textBackgroundColor))
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
