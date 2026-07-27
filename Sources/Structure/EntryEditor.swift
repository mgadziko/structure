import SwiftUI

struct EntryEditor: View {
    let entry: Entry
    @Binding var text: String
    @Binding var richTextData: Data?
    var focusedEntryID: FocusState<Entry.ID?>.Binding
    @State private var editorHeight: CGFloat = 22

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Text(entry.displayDate)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: EntryRowLayout.createdColumnWidth, alignment: .leading)
                .padding(.top, 8)

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
        }
    }
}

enum EntryRowLayout {
    static let createdColumnWidth: CGFloat = 150
}
