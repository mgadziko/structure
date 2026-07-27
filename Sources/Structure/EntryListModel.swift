import Foundation
import SwiftUI

@MainActor
final class EntryListModel: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    @Published var currentEntryID: String?
    @Published var errorMessage: String?
    @Published var sort = EntrySort()
    @Published var columns: [EntryColumn] = []
    @Published var visibilityRequest: EntryVisibilityRequest?
    @Published private var columnValues: [EntryColumnValueKey: String] = [:]

    private let store: EntryStore

    init() {
        do {
            store = try EntryStore()
            entries = try store.loadEntries()
            columns = try store.loadColumns()
            columnValues = try store.loadColumnValues()
            if entries.isEmpty {
                createEntry()
            } else {
                currentEntryID = entries.last?.id
            }
        } catch {
            fatalError("Could not initialize EntryStore: \(error)")
        }
    }

    func createEntry() {
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
    }

    func updateBody(for id: Entry.ID, body: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].body = body
        entries[index].updatedAt = Date()
        persistUpdate(entries[index])
    }

    func updateRichText(for id: Entry.ID, body: String, richTextData: Data?) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].body = body
        entries[index].richTextData = richTextData
        entries[index].updatedAt = Date()
        persistUpdate(entries[index])
    }

    var sortedEntries: [Entry] {
        guard let sortColumn = sort.column else {
            return entries
        }

        return entries.sorted { lhs, rhs in
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
        sort.select(column)
    }

    func addColumn(named title: String, placement: EntryColumnPlacement) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        let column = EntryColumn(
            id: UUID().uuidString,
            title: trimmedTitle,
            placement: placement,
            orderIndex: columns.count,
            width: EntryRowLayout.defaultUndefinedColumnWidth
        )
        columns.append(column)
        persistColumn(column)
    }

    func moveColumn(draggedColumnID: EntryColumn.ID, targetColumnID: EntryColumn.ID) {
        guard
            draggedColumnID != targetColumnID,
            let sourceIndex = columns.firstIndex(where: { $0.id == draggedColumnID }),
            let targetIndex = columns.firstIndex(where: { $0.id == targetColumnID })
        else { return }

        let targetPlacement = columns[targetIndex].placement
        var movedColumn = columns.remove(at: sourceIndex)
        movedColumn.placement = targetPlacement
        let adjustedTargetIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
        columns.insert(movedColumn, at: adjustedTargetIndex)

        for index in columns.indices {
            columns[index].orderIndex = index
        }
        persistColumnOrder()
    }

    var columnsBeforeEntry: [EntryColumn] {
        columns.filter { $0.placement == .beforeEntry }
    }

    var columnsAfterEntry: [EntryColumn] {
        columns.filter { $0.placement == .afterEntry }
    }

    func columnValue(entryID: Entry.ID, columnID: EntryColumn.ID) -> String {
        columnValues[EntryColumnValueKey(entryID: entryID, columnID: columnID)] ?? ""
    }

    func updateColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: String) {
        let key = EntryColumnValueKey(entryID: entryID, columnID: columnID)
        guard columnValues[key] != value else { return }
        columnValues[key] = value
        persistColumnValue(entryID: entryID, columnID: columnID, value: value)
        visibilityRequest = EntryVisibilityRequest(entryID: entryID)
    }

    func saveColumnValueDraft(entryID: Entry.ID, columnID: EntryColumn.ID, value: String) {
        persistColumnValue(entryID: entryID, columnID: columnID, value: value)
    }

    func requestEntryVisibility(entryID: Entry.ID) {
        visibilityRequest = EntryVisibilityRequest(entryID: entryID)
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
        let lhsValue = columnValues[EntryColumnValueKey(entryID: lhs.id, columnID: columnID)] ?? ""
        let rhsValue = columnValues[EntryColumnValueKey(entryID: rhs.id, columnID: columnID)] ?? ""
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

    private func persistInsert(_ entry: Entry) {
        do {
            try store.insert(entry)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistUpdate(_ entry: Entry) {
        do {
            try store.update(entry)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumn(_ column: EntryColumn) {
        do {
            try store.insertColumn(column)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: String) {
        do {
            try store.upsertColumnValue(entryID: entryID, columnID: columnID, value: value)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnOrder() {
        do {
            try store.updateColumnOrder(columns)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistColumnWidth(columnID: EntryColumn.ID, width: Double) {
        do {
            try store.updateColumnWidth(columnID: columnID, width: width)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}

struct EntryVisibilityRequest: Equatable {
    let id = UUID()
    let entryID: Entry.ID
}
