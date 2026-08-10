import SwiftUI

struct EntryStreamView: View {
    @ObservedObject var model: EntryListModel
    let viewScale: CGFloat
    @FocusState private var focusedEntryID: Entry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewControlsBar(
                title: model.activeViewTitle,
                activeViewID: model.activeView?.id,
                views: model.views,
                filterSummary: model.activeViewFilterSummary,
                canFilter: model.canFilterActiveView && !model.columns.isEmpty,
                canClearFilter: model.canClearActiveViewFilter,
                hasOpenLibrary: model.hasOpenLibrary,
                openView: model.openView,
                createView: model.createView,
                showCriteria: {
                    viewCriteriaPanel(for: model)
                },
                clearCriteria: {
                    confirmClearActiveViewCriteria(for: model)
                },
                rename: model.renameActiveView,
                beginEditing: clearEntryFocus
            )
            FormattingBar()
            ScrollViewReader { proxy in
                GeometryReader { geometry in
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            EntryColumnHeader(
                                sort: model.sort,
                                sortBy: model.sortBy,
                                showCreatedColumn: model.showCreatedColumn,
                                columnsBeforeEntry: model.columnsBeforeEntry,
                                columnsAfterEntry: model.columnsAfterEntry,
                                criteriaColumnIDs: model.activeViewFilterColumnIDs,
                                viewScale: viewScale,
                                availableColumnNames: model.availableColumnNames,
                                addColumn: model.addColumn,
                                moveColumn: model.moveColumn,
                                renameColumn: model.renameColumn,
                                updateColumnDefinition: model.updateColumnDefinition,
                                resizeColumn: model.resizeColumn,
                                showCriteria: {
                                    viewCriteriaPanel(for: model)
                                },
                                beginHeaderEditing: clearEntryFocus
                            )

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
                            .padding(.horizontal, EntryRowLayout.horizontalPadding * viewScale)
                            .padding(.vertical, 24 * viewScale)
                        }
                        .frame(
                            minWidth: max(tableContentWidth, geometry.size.width),
                            minHeight: geometry.size.height,
                            alignment: .topLeading
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: .textBackgroundColor))
                }
                .onAppear {
                    updateVisibleEntryOrder()
                    focusCurrentEntry(proxy: proxy, animated: false)
                }
                .onChange(of: model.visibleEntries) { _ in
                    updateVisibleEntryOrder()
                }
                .onChange(of: model.columns) { _ in
                    updateVisibleEntryOrder()
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

    private var tableContentWidth: CGFloat {
        let scaledSpacing = 18 * viewScale
        let fixedWidths = [
            EntryRowLayout.rowNumberColumnWidth,
            model.showCreatedColumn ? EntryRowLayout.createdColumnWidth : 0,
            EntryRowLayout.columnCreationControlWidth,
            EntryRowLayout.entryColumnWidth,
            EntryRowLayout.columnCreationControlWidth,
            model.columnsAfterEntry.isEmpty ? 0 : 72
        ].reduce(0) { $0 + ($1 * viewScale) }
        let beforeColumnWidth = model.columnsBeforeEntry.reduce(CGFloat(0)) { $0 + (CGFloat($1.width) * viewScale) }
        let afterColumnWidth = model.columnsAfterEntry.reduce(CGFloat(0)) { $0 + (CGFloat($1.width) * viewScale) }
        let visibleElementCount = 4
            + (model.showCreatedColumn ? 1 : 0)
            + model.columnsBeforeEntry.count
            + model.columnsAfterEntry.count
            + (model.columnsAfterEntry.isEmpty ? 0 : 1)
        let spacingWidth = CGFloat(max(visibleElementCount - 1, 0)) * scaledSpacing
        return fixedWidths
            + beforeColumnWidth
            + afterColumnWidth
            + spacingWidth
            + (EntryRowLayout.horizontalPadding * viewScale * 2)
    }

    private func focusCurrentEntry(proxy: ScrollViewProxy, animated: Bool) {
        guard let id = model.currentEntryID else { return }
        focusedEntryID = id
        EntrySelectionCoordinator.shared.focusEntry(id: id)
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .bottomLeading)
                }
            } else {
                proxy.scrollTo(id, anchor: .bottomLeading)
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

    private func updateVisibleEntryOrder() {
        EntrySelectionCoordinator.shared.updateVisibleEntryOrder(model.visibleEntries.map(\.id))
    }
}
