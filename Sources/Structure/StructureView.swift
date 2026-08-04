import Foundation

struct StructureView: Identifiable, Equatable {
    static let defaultID = "default"

    let id: String
    var title: String
    var sort: EntrySort
    var criteria: [ViewCriterion]
    var showsCreatedColumn: Bool
    var createdAt: Date
    var updatedAt: Date

    var filter: ViewFilter? {
        get { criteria.first.map { ViewFilter(columnID: $0.columnID, value: $0.value) } }
        set {
            if let newValue {
                criteria = [ViewCriterion(columnID: newValue.columnID, value: newValue.value)]
            } else {
                criteria = []
            }
        }
    }

    init(
        id: String,
        title: String,
        sort: EntrySort,
        criteria: [ViewCriterion] = [],
        filter: ViewFilter? = nil,
        showsCreatedColumn: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.sort = sort
        self.criteria = criteria
        if let filter, criteria.isEmpty {
            self.criteria = [ViewCriterion(columnID: filter.columnID, value: filter.value)]
        }
        self.showsCreatedColumn = showsCreatedColumn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ViewCriterion: Identifiable, Equatable {
    var id: String
    var columnID: EntryColumn.ID
    var value: String

    init(id: String = UUID().uuidString, columnID: EntryColumn.ID, value: String) {
        self.id = id
        self.columnID = columnID
        self.value = value
    }

    var normalizedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct ViewFilter: Equatable {
    var columnID: EntryColumn.ID
    var value: String

    var normalizedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
