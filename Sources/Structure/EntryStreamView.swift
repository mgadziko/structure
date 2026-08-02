import SwiftUI

struct EntryStreamView: View {
    @ObservedObject var model: EntryListModel
    let viewScale: CGFloat
    @FocusState private var focusedEntryID: Entry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewNameBar(
                title: model.activeViewTitle,
                rename: model.renameActiveView,
                beginEditing: clearEntryFocus
            )
            FormattingBar()
            EntryColumnHeader(
                sort: model.sort,
                sortBy: model.sortBy,
                showCreatedColumn: model.showCreatedColumn,
                columnsBeforeEntry: model.columnsBeforeEntry,
                columnsAfterEntry: model.columnsAfterEntry,
                viewScale: viewScale,
                availableColumnNames: model.availableColumnNames,
                addColumn: model.addColumn,
                moveColumn: model.moveColumn,
                renameColumn: model.renameColumn,
                updateColumnDefinition: model.updateColumnDefinition,
                resizeColumn: model.resizeColumn,
                beginHeaderEditing: clearEntryFocus
            )
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        ForEach(Array(model.visibleEntries.enumerated()), id: \.element.id) { index, entry in
                            EntryEditor(
                                entry: entry,
                                rowNumber: index + 1,
                                text: binding(for: entry.id),
                                richTextData: richTextBinding(for: entry.id),
                                showCreatedColumn: model.showCreatedColumn,
                                columnsBeforeEntry: model.columnsBeforeEntry,
                                columnsAfterEntry: model.columnsAfterEntry,
                                viewScale: viewScale,
                                columnValue: model.columnValue,
                                columnAutocompleteSource: model.columnAutocompleteSource,
                                saveColumnValueDraft: model.saveColumnValueDraft,
                                updateColumnValue: model.updateColumnValue,
                                beginEntryEditing: model.beginEntryEditing,
                                endEntryEditing: model.endEntryEditing,
                                beginColumnEditing: model.beginColumnEditing,
                                endColumnEditing: model.endColumnEditing,
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
                .onReceive(NotificationCenter.default.publisher(for: .entryFindResultSelected)) { notification in
                    guard let request = notification.object as? FindResultFocusRequest,
                          let entryID = request.cellID.entryID
                    else { return }

                    withAnimation(.easeOut(duration: 0.18)) {
                        proxy.scrollTo(entryID, anchor: .center)
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        EntrySelectionCoordinator.shared.selectFindResult(
                            cellID: request.cellID,
                            range: request.range,
                            notifyScroll: false
                        )
                    }
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
        focusedEntryID = id
        EntrySelectionCoordinator.shared.focusEntry(id: id)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(id, anchor: .bottom)
            }
            focusedEntryID = id
            EntrySelectionCoordinator.shared.focusEntry(id: id)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                EntrySelectionCoordinator.shared.focusEntry(id: id)
            }
        }
    }

    private func clearEntryFocus() {
        focusedEntryID = nil
    }
}
