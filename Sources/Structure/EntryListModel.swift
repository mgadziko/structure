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
    @Published private(set) var visibleEntries: [Entry] = []
    @Published private(set) var activeLibraryURL: URL?
    @Published private(set) var allColumnNames: [String] = []
    @Published private(set) var recentLibraryURLs: [URL] = []

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

    var activeViewTitle: String {
        activeView?.title ?? ""
    }

    var showCreatedColumn: Bool {
        activeView?.showsCreatedColumn ?? false
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
        refreshVisibleEntries(force: true)
        persistInsert(entry)
    }

    func openLibrary(at url: URL) {
        do {
            let store = try EntryStore(databaseURL: url)
            self.store = store
            activeLibraryURL = url
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
        let column = EntryColumn(
            id: UUID().uuidString,
            viewID: activeView.id,
            title: trimmedTitle,
            placement: placement,
            orderIndex: columns.count,
            width: EntryRowLayout.defaultUndefinedColumnWidth,
            definition: .none
        )
        columns.append(column)
        persistColumn(column)
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

        for index in columns.indices {
            columns[index].orderIndex = index
        }
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

    var columnsBeforeEntry: [EntryColumn] {
        columns.filter { $0.placement == .beforeEntry }
    }

    var columnsAfterEntry: [EntryColumn] {
        columns.filter { $0.placement == .afterEntry }
    }

    func columnValue(entryID: Entry.ID, columnID: EntryColumn.ID) -> EntryColumnValue {
        columnValues[EntryColumnValueKey(entryID: entryID, columnID: columnID)] ?? .empty
    }

    func updateColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: EntryColumnValue) {
        let key = EntryColumnValueKey(entryID: entryID, columnID: columnID)
        guard columnValues[key] != value else { return }
        columnValues[key] = value
        persistColumnValue(entryID: entryID, columnID: columnID, value: value)
        refreshVisibleEntries()
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

    private func compareDates(_ lhs: Date, _ rhs: Date) -> ComparisonResult {
        if lhs < rhs {
            return .orderedAscending
        }
        if lhs > rhs {
            return .orderedDescending
        }
        return .orderedSame
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
        visibleEntries = sorted(entries)
    }

    private func loadLibraryState(from store: EntryStore, createEntryIfEmpty: Bool) throws {
        views = try store.loadViews()
        if views.isEmpty {
            activeView = try store.loadDefaultView()
            views = try store.loadViews()
        } else {
            activeView = views.first(where: { $0.id == activeView?.id }) ?? views.first(where: { $0.id == StructureView.defaultID }) ?? views.first
        }
        allColumnNames = try store.loadAllColumnNames()
        sort = activeView?.sort ?? EntrySort()
        entries = try store.loadEntries()
        columns = try store.loadColumns(viewID: activeView?.id ?? StructureView.defaultID)
        columnValues = try store.loadColumnValues()
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

    private func persistColumn(_ column: EntryColumn) {
        guard let store else { return }
        do {
            try store.insertColumn(column)
            allColumnNames = try store.loadAllColumnNames()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: EntryColumnValue) {
        guard let store else { return }
        do {
            try store.upsertColumnValue(entryID: entryID, columnID: columnID, value: value)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
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
        sort = view.sort
        columns = try store.loadColumns(viewID: view.id)
        entries = try store.loadEntries()
        columnValues = try store.loadColumnValues()
        allColumnNames = try store.loadAllColumnNames()
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

    private static func loadRecentLibraryURLs() -> [URL] {
        let paths = UserDefaults.standard.stringArray(forKey: recentLibrariesPreferenceKey) ?? []
        let existingPaths = paths.filter { FileManager.default.fileExists(atPath: $0) }
        if existingPaths.count != paths.count {
            UserDefaults.standard.set(existingPaths, forKey: recentLibrariesPreferenceKey)
        }
        return existingPaths.map { URL(fileURLWithPath: $0) }
    }
}

private let lastOpenedLibraryPreferenceKey = "StructureLastOpenedLibraryURL"
private let recentLibrariesPreferenceKey = "StructureRecentLibraryURLs"

enum ColumnDropPlacement {
    case before
    case after
}
