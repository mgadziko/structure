import Foundation
import SwiftUI

@MainActor
final class EntryListModel: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    @Published var currentEntryID: String?
    @Published var errorMessage: String?
    @Published var sort = EntrySort()
    @Published private(set) var activeView: StructureView?
    @Published private(set) var views: [StructureView] = []
    @Published var columns: [EntryColumn] = []
    @Published private var columnValues: [EntryColumnValueKey: EntryColumnValue] = [:]
    @Published private var columnAssignmentInfos: [EntryColumnValueKey: AssignmentInfo] = [:]
    @Published private var categoryNamesByColumnID: [EntryColumn.ID: [String]] = [:]
    @Published private(set) var visibleEntries: [Entry] = []
    @Published private(set) var activeLibraryURL: URL?
    @Published private(set) var allColumnNames: [String] = []
    @Published private(set) var recentLibraryURLs: [URL] = []
    @Published var findText = ""

    private var store: EntryStore?
    private var editingEntryIDs: Set<Entry.ID> = []
    private var editingColumnKeys: Set<EntryColumnValueKey> = []

    init() {
        recentLibraryURLs = Self.loadRecentLibraryURLs()
        do {
            let databaseURL = try Self.initialLibraryURL()
            let store = try EntryStore(databaseURL: databaseURL)
            self.store = store
            activeLibraryURL = databaseURL
            Self.rememberLastOpenedLibrary(at: databaseURL)
            recentLibraryURLs = Self.loadRecentLibraryURLs()
            try loadLibraryState(from: store, createEntryIfEmpty: true)
        } catch {
            errorMessage = "Could not initialize EntryStore: \(error)"
            clearLibraryState()
        }
    }

    var hasOpenLibrary: Bool {
        store != nil
    }

    var hasOpenView: Bool {
        activeView != nil
    }

    var canDeleteActiveView: Bool {
        activeView.map { $0.id != StructureView.defaultID } ?? false
    }

    var activeViewTitle: String {
        activeView?.title ?? ""
    }

    var activeLibraryName: String {
        guard let activeLibraryURL else { return "" }
        return Self.libraryDisplayName(for: activeLibraryURL)
    }

    var windowTitle: String {
        guard hasOpenLibrary else { return "Structure" }
        return "Structure - \(activeLibraryName)"
    }

    var showCreatedColumn: Bool {
        activeView?.showsCreatedColumn ?? false
    }

    var activeViewFilterSummary: String? {
        let summaries = activeViewCriteriaSummaries
        guard !summaries.isEmpty else { return nil }
        return summaries.joined(separator: " and ")
    }

    var activeViewCriteriaSummaries: [String] {
        guard let criteria = activeView?.criteria, !criteria.isEmpty else { return [] }
        return criteria.compactMap { criterion in
            guard let column = columns.first(where: { $0.id == criterion.columnID }) else { return nil }
            return "\(column.title) = \(criterion.value)"
        }
    }

    var canFilterActiveView: Bool {
        activeView.map { $0.id != StructureView.defaultID } ?? false
    }

    var canClearActiveViewFilter: Bool {
        !(activeView?.criteria.isEmpty ?? true)
    }

    var activeViewFilterColumnIDs: Set<EntryColumn.ID> {
        Set(activeView?.criteria.map(\.columnID) ?? [])
    }

    var canSaveActiveCriteriaAsCategoryRule: Bool {
        guard canFilterActiveView,
              !(activeView?.criteria.isEmpty ?? true)
        else { return false }
        return columns.contains { $0.definition == .category }
    }

    var categoryRuleTargetColumns: [EntryColumn] {
        columns
            .filter { $0.definition == .category }
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    var availableColumnNames: [String] {
        let used = Set(columns.map { normalizedName($0.title) })
        return allColumnNames.filter { !used.contains(normalizedName($0)) }
    }

    func createEntry() {
        guard store != nil, activeView != nil else {
            errorMessage = "Open or create a View before adding Entries."
            return
        }
        let now = Date()
        let entry = Entry(
            id: UUID().uuidString,
            body: "",
            richTextData: nil,
            createdAt: now,
            updatedAt: now,
            capturedAt: now,
            deletedAt: nil
        )
        entries.append(entry)
        currentEntryID = entry.id
        persistInsert(entry)

        for criterion in activeView?.criteria ?? [] {
            let value = EntryColumnValue(text: criterion.value, richTextData: nil)
            columnValues[EntryColumnValueKey(entryID: entry.id, columnID: criterion.columnID)] = value
            persistColumnValue(entryID: entry.id, columnID: criterion.columnID, value: value)
        }
        applyCategoryRules(toEntryID: entry.id)

        refreshVisibleEntries(force: true)
    }

    func openLibrary(at url: URL) {
        do {
            let store = try EntryStore(databaseURL: url)
            self.store = store
            activeLibraryURL = url
            activeView = nil
            Self.rememberLastOpenedLibrary(at: url)
            recentLibraryURLs = Self.loadRecentLibraryURLs()
            try loadLibraryState(from: store, createEntryIfEmpty: true)
            errorMessage = nil
        } catch {
            errorMessage = "Could not open Library: \(error)"
        }
    }

    func createLibrary(at url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            let store = try EntryStore(databaseURL: url)
            self.store = store
            activeLibraryURL = url
            activeView = nil
            Self.rememberLastOpenedLibrary(at: url)
            recentLibraryURLs = Self.loadRecentLibraryURLs()
            try loadLibraryState(from: store, createEntryIfEmpty: true)
            errorMessage = nil
        } catch {
            errorMessage = "Could not create Library: \(error)"
        }
    }

    func closeLibrary() {
        store = nil
        activeLibraryURL = nil
        clearLibraryState()
        errorMessage = nil
    }

    func createView() {
        guard let store else {
            errorMessage = "Open or create a Library before adding Views."
            return
        }

        let now = Date()
        let view = StructureView(
            id: UUID().uuidString,
            title: nextViewName(),
            sort: EntrySort(column: .body, direction: .ascending),
            showsCreatedColumn: false,
            createdAt: now,
            updatedAt: now
        )

        do {
            try store.insertView(view)
            try reloadViews(activeViewID: view.id)
            errorMessage = nil
        } catch {
            errorMessage = "Could not create View: \(error)"
        }
    }

    func openView(id: StructureView.ID) {
        guard store != nil else { return }
        do {
            try activateView(id: id)
            errorMessage = nil
        } catch {
            errorMessage = "Could not open View: \(error)"
        }
    }

    func closeView() {
        activeView = nil
        columns = []
        currentEntryID = nil
        visibleEntries = []
        editingEntryIDs = []
        editingColumnKeys = []
    }

    func deleteActiveView() {
        guard let store, let activeView, canDeleteActiveView else { return }
        do {
            try store.deleteView(viewID: activeView.id)
            try reloadViews(activeViewID: StructureView.defaultID)
            errorMessage = nil
        } catch {
            errorMessage = "Could not delete View: \(error)"
        }
    }

    func renameActiveView(to title: String) {
        guard let store, let activeView else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              normalizedName(trimmedTitle) != normalizedName(activeView.title),
              isUniqueViewName(trimmedTitle)
        else { return }

        do {
            try store.updateViewTitle(viewID: activeView.id, title: trimmedTitle)
            try reloadViews(activeViewID: activeView.id)
            errorMessage = nil
        } catch {
            errorMessage = "Could not rename View: \(error)"
        }
    }

    func updateActiveViewFilter(columnID: EntryColumn.ID?, value: String) {
        if let columnID {
            var criteria = activeView?.criteria ?? []
            if let index = criteria.firstIndex(where: { $0.columnID == columnID }) {
                criteria[index].value = value
            } else {
                criteria.append(ViewCriterion(columnID: columnID, value: value))
            }
            updateActiveViewCriteria(criteria)
        } else {
            updateActiveViewCriteria([])
        }
    }

    func updateActiveViewCriteria(_ criteria: [ViewCriterion]) {
        guard let store, var activeView else { return }
        let cleanedCriteria = criteria.compactMap { criterion -> ViewCriterion? in
            let trimmedValue = criterion.value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !criterion.columnID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !trimmedValue.isEmpty
            else { return nil }
            return ViewCriterion(id: criterion.id, columnID: criterion.columnID, value: trimmedValue)
        }

        do {
            try store.updateViewCriteria(viewID: activeView.id, criteria: cleanedCriteria)
            activeView.criteria = cleanedCriteria
            self.activeView = activeView
            try reloadViews(activeViewID: activeView.id)
            errorMessage = nil
        } catch {
            errorMessage = "Could not update View criteria: \(error)"
        }
    }

    func removeActiveViewCriteria(ids: Set<ViewCriterion.ID>) {
        guard let activeView, !ids.isEmpty else { return }
        updateActiveViewCriteria(activeView.criteria.filter { !ids.contains($0.id) })
    }

    func saveActiveViewCriteriaAsCategoryRule(targetColumnID: EntryColumn.ID, categoryName: String) {
        guard let store,
              let activeView,
              !activeView.criteria.isEmpty,
              let targetColumn = columns.first(where: { $0.id == targetColumnID && $0.definition == .category })
        else { return }

        let trimmedCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCategoryName.isEmpty else { return }

        let ruleCriteria = activeView.criteria.compactMap { criterion -> CategoryRuleCriterion? in
            guard let sourceColumn = columns.first(where: { $0.id == criterion.columnID }) else { return nil }
            return CategoryRuleCriterion(
                sourceColumnDefinitionID: sourceColumn.definitionID,
                value: criterion.value
            )
        }
        guard !ruleCriteria.isEmpty else { return }

        do {
            _ = try store.upsertCategoryRule(
                targetColumnDefinitionID: targetColumn.definitionID,
                categoryName: trimmedCategoryName,
                criteria: ruleCriteria
            )
            try store.applyCategoryRulesToAllEntries()
            columnValues = try store.loadColumnValues()
            columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
            try reloadCategoryNames()
            refreshVisibleEntries(force: true)
            errorMessage = nil
        } catch {
            errorMessage = "Could not save Category rule: \(error)"
        }
    }

    func updateBody(for id: Entry.ID, body: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].body = body
        entries[index].updatedAt = Date()
        refreshVisibleEntries()
        persistUpdate(entries[index])
    }

    func updateRichText(for id: Entry.ID, body: String, richTextData: Data?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].body = body
        entries[index].richTextData = richTextData
        entries[index].updatedAt = Date()
        refreshVisibleEntries()
        persistUpdate(entries[index])
    }

    private func sorted(_ sourceEntries: [Entry]) -> [Entry] {
        guard let sortColumn = sort.column else {
            return sourceEntries
        }

        return sourceEntries.sorted { lhs, rhs in
            let comparison: ComparisonResult
            switch sortColumn {
            case .created:
                comparison = compareDates(lhs.createdAt, rhs.createdAt)
            case .body:
                comparison = compareEntryBodies(lhs, rhs)
            case .userColumn(let columnID):
                comparison = compareColumnValues(columnID: columnID, lhs: lhs, rhs: rhs)
            }

            switch sort.direction {
            case .ascending:
                return comparison == .orderedAscending
            case .descending:
                return comparison == .orderedDescending
            }
        }
    }

    func sortBy(_ column: EntrySortColumn) {
        guard activeView != nil else { return }
        sort.select(column)
        activeView?.sort = sort
        persistViewSort()
        refreshVisibleEntries(force: true)
    }

    func addColumn(named title: String, placement: EntryColumnPlacement) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let activeView,
              !trimmedTitle.isEmpty,
              isUniqueColumnNameInActiveView(trimmedTitle)
        else { return }

        let template = try? store?.loadColumnTemplate(named: trimmedTitle)
        let insertionIndex = columnInsertionIndex(for: placement)
        let column = EntryColumn(
            id: UUID().uuidString,
            definitionID: template?.definitionID,
            viewID: activeView.id,
            title: template?.title ?? trimmedTitle,
            placement: placement,
            orderIndex: insertionIndex,
            width: template?.width ?? EntryRowLayout.defaultUndefinedColumnWidth,
            definition: template?.definition ?? .none
        )
        columns.insert(column, at: insertionIndex)
        updateColumnOrderIndexes()
        persistColumn(column, copyingValuesFrom: template?.id)
        persistColumnOrder()
        refreshAvailableColumnNames()
    }

    func moveColumn(draggedColumnID: EntryColumn.ID, targetColumnID: EntryColumn.ID) {
        moveColumn(draggedColumnID: draggedColumnID, targetColumnID: targetColumnID, placement: .before)
    }

    func moveColumn(draggedColumnID: EntryColumn.ID, targetColumnID: EntryColumn.ID, placement: ColumnDropPlacement) {
        guard
            draggedColumnID != targetColumnID,
            let sourceIndex = columns.firstIndex(where: { $0.id == draggedColumnID }),
            let targetIndex = columns.firstIndex(where: { $0.id == targetColumnID })
        else { return }

        let targetPlacement = columns[targetIndex].placement
        var movedColumn = columns.remove(at: sourceIndex)
        movedColumn.placement = targetPlacement
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        let insertionIndex: Int
        switch placement {
        case .before:
            insertionIndex = adjustedTargetIndex
        case .after:
            insertionIndex = min(adjustedTargetIndex + 1, columns.count)
        }
        columns.insert(movedColumn, at: insertionIndex)

        updateColumnOrderIndexes()
        persistColumnOrder()
    }

    func renameColumn(columnID: EntryColumn.ID, title: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let index = columns.firstIndex(where: { $0.id == columnID }),
              normalizedName(columns[index].title) == normalizedName(trimmedTitle) || isUniqueColumnNameInActiveView(trimmedTitle),
              columns[index].title != trimmedTitle
        else { return }

        columns[index].title = trimmedTitle
        persistColumnTitle(columnID: columnID, title: trimmedTitle)
        refreshAvailableColumnNames()
    }

    func updateColumnDefinition(columnID: EntryColumn.ID, definition: EntryColumnDefinition) {
        guard let index = columns.firstIndex(where: { $0.id == columnID }),
              columns[index].definition != definition
        else { return }

        columns[index].definition = definition
        persistColumnDefinition(columnID: columnID, definition: definition)
    }

    var columnsBeforeEntry: [EntryColumn] {
        columns.filter { $0.placement == .beforeEntry }
    }

    var columnsAfterEntry: [EntryColumn] {
        columns.filter { $0.placement == .afterEntry }
    }

    func columnValue(entryID: Entry.ID, columnID: EntryColumn.ID) -> EntryColumnValue {
        columnValues[EntryColumnValueKey(entryID: entryID, columnID: columnID)] ?? .empty
    }

    func columnAssignmentInfo(entryID: Entry.ID, columnID: EntryColumn.ID) -> AssignmentInfo? {
        columnAssignmentInfos[EntryColumnValueKey(entryID: entryID, columnID: columnID)]
    }

    func columnAutocompleteSource(entryID: Entry.ID, columnID: EntryColumn.ID) -> String {
        let visibleColumnValues = visibleEntries
            .filter { $0.id != entryID }
            .compactMap { entry in
                let value = columnValue(entryID: entry.id, columnID: columnID).text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }

        let categoryNames = columns.first(where: { $0.id == columnID })?.definition == .category
            ? categoryNamesByColumnID[columnID] ?? []
            : []

        return deduplicatedAutocompleteLines(categoryNames + visibleColumnValues)
            .joined(separator: "\n")
    }

    func criteriaValueSuggestions(columnID: EntryColumn.ID) -> [String] {
        let values = entries.compactMap { entry in
            let value = columnValue(entryID: entry.id, columnID: columnID).text
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
        return deduplicatedAutocompleteLines(values)
    }

    func updateColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: EntryColumnValue) {
        let key = EntryColumnValueKey(entryID: entryID, columnID: columnID)
        guard columnValues[key] != value else { return }
        columnValues[key] = value
        persistColumnValue(entryID: entryID, columnID: columnID, value: value)
        applyCategoryRules(toEntryID: entryID)
        refreshVisibleEntries()
    }

    func markColumnValueExplicit(entryID: Entry.ID, columnID: EntryColumn.ID) {
        guard let store else { return }
        do {
            try store.markColumnValueExplicit(entryID: entryID, columnID: columnID)
            columnValues = try store.loadColumnValues()
            columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
            try reloadCategoryNames()
            errorMessage = nil
        } catch {
            errorMessage = "Could not mark assignment explicit: \(error)"
        }
    }

    func saveColumnValueDraft(entryID: Entry.ID, columnID: EntryColumn.ID, value: EntryColumnValue) {
        persistColumnValue(entryID: entryID, columnID: columnID, value: value)
    }

    func beginEntryEditing(entryID: Entry.ID) {
        editingEntryIDs.insert(entryID)
    }

    func endEntryEditing(entryID: Entry.ID) {
        editingEntryIDs.remove(entryID)
        refreshVisibleEntries(force: true)
    }

    func beginColumnEditing(entryID: Entry.ID, columnID: EntryColumn.ID) {
        editingColumnKeys.insert(EntryColumnValueKey(entryID: entryID, columnID: columnID))
    }

    func endColumnEditing(entryID: Entry.ID, columnID: EntryColumn.ID) {
        editingColumnKeys.remove(EntryColumnValueKey(entryID: entryID, columnID: columnID))
        refreshVisibleEntries(force: true)
    }

    func resizeColumn(columnID: EntryColumn.ID, width: Double) {
        guard let index = columns.firstIndex(where: { $0.id == columnID }) else { return }
        let clampedWidth = min(max(width, EntryRowLayout.minimumUndefinedColumnWidth), EntryRowLayout.maximumUndefinedColumnWidth)
        guard abs(columns[index].width - clampedWidth) > 0.5 else { return }
        columns[index].width = clampedWidth
        persistColumnWidth(columnID: columnID, width: clampedWidth)
    }

    func findNext(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        findText = trimmedQuery

        let cells = searchableCells()
        guard !cells.isEmpty else { return }

        let anchor = EntrySelectionCoordinator.shared.currentFindAnchor()
        let anchorIndex = anchor.flatMap { anchor in
            cells.firstIndex { $0.id == anchor.cellID }
        }
        let startIndex = anchorIndex ?? 0
        let startLocation = anchor.map { $0.selectedRange.location + $0.selectedRange.length } ?? 0

        if let result = find(trimmedQuery, in: cells[startIndex], startingAt: startLocation) {
            EntrySelectionCoordinator.shared.selectFindResult(cellID: result.cellID, range: result.range)
            return
        }

        if cells.count > 1 {
            let nextIndex = cells.index(after: startIndex)
            if nextIndex < cells.endIndex,
               let result = find(trimmedQuery, in: cells[nextIndex..<cells.endIndex], startingAt: 0) {
                EntrySelectionCoordinator.shared.selectFindResult(cellID: result.cellID, range: result.range)
                return
            }
        }

        if startIndex > 0,
           let result = find(trimmedQuery, in: cells[..<startIndex], startingAt: 0) {
            EntrySelectionCoordinator.shared.selectFindResult(cellID: result.cellID, range: result.range)
            return
        }

        if startLocation > 0,
           let result = find(trimmedQuery, in: cells[startIndex], startingAt: 0, endingBefore: startLocation) {
            EntrySelectionCoordinator.shared.selectFindResult(cellID: result.cellID, range: result.range)
            return
        }

        errorMessage = "Could not find \"\(trimmedQuery)\"."
    }

    private func compareDates(_ lhs: Date, _ rhs: Date) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }
        if lhs > rhs {
            return .orderedDescending
        }
        return .orderedSame
    }

    private func searchableCells() -> [SearchableCell] {
        visibleEntries.flatMap { entry in
            columnsBeforeEntry.map { column in
                SearchableCell(
                    id: .column(entryID: entry.id, columnID: column.id),
                    text: columnValue(entryID: entry.id, columnID: column.id).text
                )
            }
            + [SearchableCell(id: .entry(entry.id), text: entry.body)]
            + columnsAfterEntry.map { column in
                SearchableCell(
                    id: .column(entryID: entry.id, columnID: column.id),
                    text: columnValue(entryID: entry.id, columnID: column.id).text
                )
            }
        }
    }

    private func find(
        _ query: String,
        in cells: ArraySlice<SearchableCell>,
        startingAt startLocation: Int
    ) -> FindResult? {
        for cell in cells {
            if let result = find(query, in: cell, startingAt: startLocation) {
                return result
            }
        }
        return nil
    }

    private func find(
        _ query: String,
        in cell: SearchableCell,
        startingAt startLocation: Int,
        endingBefore endLocation: Int? = nil
    ) -> FindResult? {
        let nsText = cell.text as NSString
        let safeStart = min(max(startLocation, 0), nsText.length)
        let safeEnd = min(max(endLocation ?? nsText.length, safeStart), nsText.length)
        let searchRange = NSRange(location: safeStart, length: safeEnd - safeStart)
        let range = nsText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange)
        guard range.location != NSNotFound else { return nil }
        return FindResult(cellID: cell.id, range: range)
    }

    private func compareEntryBodies(_ lhs: Entry, _ rhs: Entry) -> ComparisonResult {
        let bodyComparison = lhs.body.localizedStandardCompare(rhs.body)
        if bodyComparison != .orderedSame {
            return bodyComparison
        }

        let dateComparison = compareDates(lhs.createdAt, rhs.createdAt)
        if dateComparison != .orderedSame {
            return dateComparison
        }

        return lhs.id.localizedStandardCompare(rhs.id)
    }

    private func compareColumnValues(columnID: EntryColumn.ID, lhs: Entry, rhs: Entry) -> ComparisonResult {
        let lhsValue = columnValues[EntryColumnValueKey(entryID: lhs.id, columnID: columnID)]?.text ?? ""
        let rhsValue = columnValues[EntryColumnValueKey(entryID: rhs.id, columnID: columnID)]?.text ?? ""
        let valueComparison = lhsValue.localizedStandardCompare(rhsValue)
        if valueComparison != .orderedSame {
            return valueComparison
        }

        let dateComparison = compareDates(lhs.createdAt, rhs.createdAt)
        if dateComparison != .orderedSame {
            return dateComparison
        }

        return lhs.id.localizedStandardCompare(rhs.id)
    }

    private var isEditing: Bool {
        !editingEntryIDs.isEmpty || !editingColumnKeys.isEmpty
    }

    private func refreshVisibleEntries(force: Bool = false) {
        guard force || !isEditing else { return }
        visibleEntries = sorted(filtered(entries))
    }

    private func filtered(_ sourceEntries: [Entry]) -> [Entry] {
        guard let criteria = activeView?.criteria, !criteria.isEmpty else { return sourceEntries }
        return sourceEntries.filter { entry in
            criteria.allSatisfy { criterion in
                columnValue(entryID: entry.id, columnID: criterion.columnID)
                    .text
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() == criterion.normalizedValue
            }
        }
    }

    private func loadLibraryState(from store: EntryStore, createEntryIfEmpty: Bool) throws {
        views = try store.loadViews()
        if views.isEmpty {
            activeView = try store.loadDefaultView()
            views = try store.loadViews()
        } else {
            let rememberedViewID = activeLibraryURL.flatMap { Self.rememberedActiveViewID(for: $0) }
            activeView = views.first(where: { $0.id == rememberedViewID })
                ?? views.first(where: { $0.id == activeView?.id })
                ?? views.first(where: { $0.id == StructureView.defaultID })
                ?? views.first
        }
        allColumnNames = try store.loadAllColumnNames()
        sort = activeView?.sort ?? EntrySort()
        entries = try store.loadEntries()
        columns = try store.loadColumns(viewID: activeView?.id ?? StructureView.defaultID)
        columnValues = try store.loadColumnValues()
        columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
        try reloadCategoryNames()
        editingEntryIDs = []
        editingColumnKeys = []

        if entries.isEmpty, createEntryIfEmpty {
            createEntry()
        } else {
            currentEntryID = entries.last?.id
            refreshVisibleEntries(force: true)
        }
    }

    private func clearLibraryState() {
        activeView = nil
        views = []
        sort = EntrySort()
        entries = []
        columns = []
        columnValues = [:]
        columnAssignmentInfos = [:]
        categoryNamesByColumnID = [:]
        allColumnNames = []
        currentEntryID = nil
        visibleEntries = []
        editingEntryIDs = []
        editingColumnKeys = []
    }

    private func persistInsert(_ entry: Entry) {
        guard let store else { return }
        do {
            try store.insert(entry)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistUpdate(_ entry: Entry) {
        guard let store else { return }
        do {
            try store.update(entry)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumn(_ column: EntryColumn, copyingValuesFrom sourceColumnID: EntryColumn.ID? = nil) {
        guard let store else { return }
        do {
            try store.insertColumn(column)
            if let sourceColumnID {
                try store.copyColumnValues(from: sourceColumnID, to: column.id)
                columnValues = try store.loadColumnValues()
                columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
            }
            allColumnNames = try store.loadAllColumnNames()
            try reloadCategoryNames()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: EntryColumnValue) {
        guard let store else { return }
        do {
            try store.upsertColumnValue(entryID: entryID, columnID: columnID, value: value)
            columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
            try reloadCategoryNames()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func applyCategoryRules(toEntryID entryID: Entry.ID) {
        guard let store else { return }
        do {
            try store.applyCategoryRules(toEntryID: entryID)
            columnValues = try store.loadColumnValues()
            columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
            try reloadCategoryNames()
            errorMessage = nil
        } catch {
            errorMessage = "Could not apply Category rules: \(error)"
        }
    }

    private func persistColumnOrder() {
        guard let store else { return }
        do {
            try store.updateColumnOrder(columns)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnWidth(columnID: EntryColumn.ID, width: Double) {
        guard let store else { return }
        do {
            try store.updateColumnWidth(columnID: columnID, width: width)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnTitle(columnID: EntryColumn.ID, title: String) {
        guard let store else { return }
        do {
            try store.updateColumnTitle(columnID: columnID, title: title)
            allColumnNames = try store.loadAllColumnNames()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnDefinition(columnID: EntryColumn.ID, definition: EntryColumnDefinition) {
        guard let store else { return }
        do {
            try store.updateColumnDefinition(columnID: columnID, definition: definition)
            columns = try store.loadColumns(viewID: activeView?.id ?? StructureView.defaultID)
            allColumnNames = try store.loadAllColumnNames()
            try reloadCategoryNames()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistViewSort() {
        guard let store, let activeView else { return }
        do {
            try store.updateViewSort(viewID: activeView.id, sort: sort)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func reloadViews(activeViewID: StructureView.ID?) throws {
        guard let store else { return }
        views = try store.loadViews()
        if let activeViewID, views.contains(where: { $0.id == activeViewID }) {
            try activateView(id: activeViewID)
        } else if let firstView = views.first {
            try activateView(id: firstView.id)
        } else {
            closeView()
        }
    }

    private func activateView(id: StructureView.ID) throws {
        guard let store, let view = try store.loadView(id: id) else { return }
        activeView = view
        if let activeLibraryURL {
            Self.rememberActiveViewID(view.id, for: activeLibraryURL)
        }
        sort = view.sort
        columns = try store.loadColumns(viewID: view.id)
        entries = try store.loadEntries()
        columnValues = try store.loadColumnValues()
        columnAssignmentInfos = try store.loadColumnValueAssignmentInfo()
        allColumnNames = try store.loadAllColumnNames()
        try reloadCategoryNames()
        currentEntryID = entries.last?.id
        editingEntryIDs = []
        editingColumnKeys = []
        refreshVisibleEntries(force: true)
    }

    private func refreshAvailableColumnNames() {
        guard let store else { return }
        do {
            allColumnNames = try store.loadAllColumnNames()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func reloadCategoryNames() throws {
        guard let store else {
            categoryNamesByColumnID = [:]
            return
        }

        var namesByColumn: [EntryColumn.ID: [String]] = [:]
        for column in columns where column.definition == .category {
            namesByColumn[column.id] = try store.loadCategoryNames(columnID: column.id)
        }
        categoryNamesByColumnID = namesByColumn
    }

    private func deduplicatedAutocompleteLines(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for value in values {
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedValue.isEmpty else { continue }
            if seen.insert(normalizedName(trimmedValue)).inserted {
                result.append(trimmedValue)
            }
        }
        return result
    }

    private func nextViewName() -> String {
        let existingNames = Set(views.map { normalizedName($0.title) })
        var index = 1
        while existingNames.contains(normalizedName("New View \(index)")) {
            index += 1
        }
        return "New View \(index)"
    }

    private func isUniqueViewName(_ title: String) -> Bool {
        let normalized = normalizedName(title)
        return !views.contains { normalizedName($0.title) == normalized }
    }

    private func isUniqueColumnNameInActiveView(_ title: String) -> Bool {
        let normalized = normalizedName(title)
        return !columns.contains { normalizedName($0.title) == normalized }
    }

    private func columnInsertionIndex(for placement: EntryColumnPlacement) -> Int {
        switch placement {
        case .beforeEntry:
            return columns.lastIndex(where: { $0.placement == .beforeEntry }).map { $0 + 1 } ?? 0
        case .afterEntry:
            return columns.firstIndex(where: { $0.placement == .afterEntry }) ?? columns.count
        }
    }

    private func updateColumnOrderIndexes() {
        for index in columns.indices {
            columns[index].orderIndex = index
        }
    }

    private func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func lastOpenedLibraryURL() -> URL? {
        guard let path = UserDefaults.standard.string(forKey: lastOpenedLibraryPreferenceKey),
              !path.isEmpty
        else { return nil }
        return URL(fileURLWithPath: path)
    }

    private static func initialLibraryURL() throws -> URL {
        if let lastOpenedURL = lastOpenedLibraryURL(),
           FileManager.default.fileExists(atPath: lastOpenedURL.path) {
            return lastOpenedURL
        }
        let legacyDefaultURL = try EntryStore.legacyDefaultDatabaseURL
        if FileManager.default.fileExists(atPath: legacyDefaultURL.path) {
            return legacyDefaultURL
        }
        return try EntryStore.defaultDatabaseURL
    }

    private static func rememberLastOpenedLibrary(at url: URL) {
        UserDefaults.standard.set(url.path, forKey: lastOpenedLibraryPreferenceKey)
        rememberRecentLibrary(at: url)
    }

    private static func rememberRecentLibrary(at url: URL) {
        let normalizedPath = url.path
        let existingPaths = UserDefaults.standard.stringArray(forKey: recentLibrariesPreferenceKey) ?? []
        let paths = ([normalizedPath] + existingPaths.filter { $0 != normalizedPath })
            .filter { FileManager.default.fileExists(atPath: $0) }
            .prefix(7)
        UserDefaults.standard.set(Array(paths), forKey: recentLibrariesPreferenceKey)
    }

    private static func rememberedActiveViewID(for url: URL) -> StructureView.ID? {
        let rememberedViews = UserDefaults.standard.dictionary(forKey: lastActiveViewByLibraryPreferenceKey) as? [String: String]
        return rememberedViews?[url.path]
    }

    private static func rememberActiveViewID(_ viewID: StructureView.ID, for url: URL) {
        var rememberedViews = UserDefaults.standard.dictionary(forKey: lastActiveViewByLibraryPreferenceKey) as? [String: String] ?? [:]
        rememberedViews[url.path] = viewID
        UserDefaults.standard.set(rememberedViews, forKey: lastActiveViewByLibraryPreferenceKey)
    }

    private static func loadRecentLibraryURLs() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: recentLibrariesPreferenceKey) ?? []
        let existingPaths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        if existingPaths.count != paths.count {
            UserDefaults.standard.set(existingPaths, forKey: recentLibrariesPreferenceKey)
        }
        return existingPaths.map { URL(fileURLWithPath: $0) }
    }

    private static func libraryDisplayName(for url: URL) -> String {
        let defaultURL = try? EntryStore.defaultDatabaseURL
        let legacyDefaultURL = try? EntryStore.legacyDefaultDatabaseURL
        if url.path == defaultURL?.path || url.path == legacyDefaultURL?.path {
            return "Initial Library"
        }
        return url.deletingPathExtension().lastPathComponent
    }
}

private let lastOpenedLibraryPreferenceKey = "StructureLastOpenedLibraryURL"
private let recentLibrariesPreferenceKey = "StructureRecentLibraryURLs"
private let lastActiveViewByLibraryPreferenceKey = "StructureLastActiveViewByLibrary"

enum ColumnDropPlacement {
    case before
    case after
}

private struct SearchableCell {
    let id: StructureCellID
    let text: String
}

private struct FindResult {
    let cellID: StructureCellID
    let range: NSRange
}
