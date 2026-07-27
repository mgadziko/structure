import SwiftUI

struct EntryEditor: View {
    let entry: Entry
    @Binding var text: String
    @Binding var richTextData: Data?
    let columnsBeforeEntry: [EntryColumn]
    let columnsAfterEntry: [EntryColumn]
    let columnValueBinding: (Entry.ID, EntryColumn.ID) -> Binding<String>
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
                    text: columnValueBinding(entry.id, column.id),
                    columnTitle: column.title
                )
            }

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

            ForEach(columnsAfterEntry) { column in
                UndefinedColumnCell(
                    text: columnValueBinding(entry.id, column.id),
                    columnTitle: column.title
                )
            }
        }
    }
}

enum EntryRowLayout {
    static let horizontalPadding: CGFloat = 38
    static let createdColumnWidth: CGFloat = 150
    static let undefinedColumnWidth: CGFloat = 120
    static let entryColumnWidth: CGFloat = 300
}

private struct UndefinedColumnCell: View {
    @Binding var text: String
    let columnTitle: String

    var body: some View {
        TextField("", text: $text, prompt: Text("..."))
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .frame(width: EntryRowLayout.undefinedColumnWidth, height: 24, alignment: .topLeading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.22))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
            )
            .accessibilityLabel("\(columnTitle) value")
    }
}
