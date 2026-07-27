import Foundation

enum EntrySortColumn {
    case created
    case body
}

enum EntrySortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

struct EntrySort {
    var column: EntrySortColumn?
    var direction: EntrySortDirection = .ascending

    mutating func select(_ selectedColumn: EntrySortColumn) {
        if column == selectedColumn {
            direction.toggle()
        } else {
            column = selectedColumn
            direction = .ascending
        }
    }
}
