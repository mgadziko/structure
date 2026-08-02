import Foundation

struct StructureView: Identifiable, Equatable {
    static let defaultID = "default"

    let id: String
    var title: String
    var sort: EntrySort
    var filter: ViewFilter?
    var showsCreatedColumn: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String,
        title: String,
        sort: EntrySort,
        filter: ViewFilter? = nil,
        showsCreatedColumn: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.sort = sort
        self.filter = filter
        self.showsCreatedColumn = showsCreatedColumn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct ViewFilter: Equatable {
    var columnID: EntryColumn.ID
    var value: String

    var normalizedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
