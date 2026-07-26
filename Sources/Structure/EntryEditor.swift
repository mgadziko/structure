import SwiftUI

struct EntryEditor: View {
    let entry: Entry
    @Binding var text: String
    var focusedEntryID: FocusState<Entry.ID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.displayDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .focused(focusedEntryID, equals: entry.id)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(.horizontal, -5)
                .accessibilityLabel("Entry created \(entry.displayDate)")
        }
    }
}
