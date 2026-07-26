import SwiftUI

struct EntryStreamView: View {
    @ObservedObject var model: EntryListModel
    @FocusState private var focusedEntryID: Entry.ID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(model.entries) { entry in
                        EntryEditor(
                            entry: entry,
                            text: binding(for: entry.id),
                            focusedEntryID: $focusedEntryID
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 38)
                .padding(.vertical, 32)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear {
                focusCurrentEntry(proxy: proxy, animated: false)
            }
            .onChange(of: model.currentEntryID) { id in
                focusCurrentEntry(proxy: proxy, animated: id != nil)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.regularMaterial)
                    .padding()
            }
        }
    }

    private func binding(for id: Entry.ID) -> Binding<String> {
        Binding(
            get: { model.entries.first(where: { $0.id == id })?.body ?? "" },
            set: { model.updateBody(for: id, body: $0) }
        )
    }

    private func focusCurrentEntry(proxy: ScrollViewProxy, animated: Bool) {
        guard let id = model.currentEntryID else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(id, anchor: .bottom)
            }
            focusedEntryID = id
        }
    }
}
