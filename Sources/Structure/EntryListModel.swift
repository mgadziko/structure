import Foundation
import SwiftUI

@MainActor
final class EntryListModel: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    @Published var currentEntryID: String?
    @Published var errorMessage: String?
    @Published var sort = EntrySort()
    @Published var columns: [EntryColumn] = []
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
            orderIndex: columns.count
        )
        columns.append(column)
        persistColumn(column)
    }

    var columnsBeforeEntry: [EntryColumn] {
        columns.filter { $0.placement == .beforeEntry }
    }

    var columnsAfterEntry: [EntryColumn] {
        columns.filter { $0.placement == .afterEntry }
    }

    func columnValueBinding(entryID: Entry.ID, columnID: EntryColumn.ID) -> Binding<String> {
        let key = EntryColumnValueKey(entryID: entryID, columnID: columnID)
        return Binding(
            get: { self.columnValues[key] ?? "" },
            set: { value in
                self.columnValues[key] = value
                self.persistColumnValue(entryID: entryID, columnID: columnID, value: value)
            }
        )
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
}
