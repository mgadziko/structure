import SwiftUI

struct EntryStreamView: View {
    @ObservedObject var model: EntryListModel
    @FocusState private var focusedEntryID: Entry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FormattingBar()
            EntryColumnHeader(
                sort: model.sort,
                sortBy: model.sortBy,
                columnsBeforeEntry: model.columnsBeforeEntry,
                columnsAfterEntry: model.columnsAfterEntry,
                addColumn: model.addColumn,
                moveColumn: model.moveColumn,
                resizeColumn: model.resizeColumn
            )
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(model.sortedEntries) { entry in
                            EntryEditor(
                                entry: entry,
                                text: binding(for: entry.id),
                                richTextData: richTextBinding(for: entry.id),
                                columnsBeforeEntry: model.columnsBeforeEntry,
                                columnsAfterEntry: model.columnsAfterEntry,
                                columnValue: model.columnValue,
                                saveColumnValueDraft: model.saveColumnValueDraft,
                                updateColumnValue: model.updateColumnValue,
                                requestEntryVisibility: model.requestEntryVisibility,
                                focusedEntryID: $focusedEntryID
                            )
                            .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, EntryRowLayout.horizontalPadding)
                    .padding(.vertical, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor))
                .onAppear {
                    focusCurrentEntry(proxy: proxy, animated: false)
                }
                .onChange(of: model.currentEntryID) { id in
                    focusCurrentEntry(proxy: proxy, animated: id != nil)
                }
                .onChange(of: model.visibilityRequest) { request in
                    keepEntryVisible(request, proxy: proxy)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(nsColor: .textBackgroundColor))
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
            set: { body in
                let richTextData = model.entries.first(where: { $0.id == id })?.richTextData
                model.updateRichText(for: id, body: body, richTextData: richTextData)
            }
        )
    }

    private func richTextBinding(for id: Entry.ID) -> Binding<Data?> {
        Binding(
            get: { model.entries.first(where: { $0.id == id })?.richTextData },
            set: { richTextData in
                let body = model.entries.first(where: { $0.id == id })?.body ?? ""
                model.updateRichText(for: id, body: body, richTextData: richTextData)
            }
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

    private func keepEntryVisible(_ request: EntryVisibilityRequest?, proxy: ScrollViewProxy) {
        guard let request else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.18)) {
                proxy.scrollTo(request.entryID, anchor: .center)
            }
        }
    }
}
