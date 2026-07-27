import Foundation

enum EntryColumnPlacement {
    case beforeEntry
    case afterEntry

    init(rawValue: String) {
        switch rawValue {
        case "before_entry":
            self = .beforeEntry
        default:
            self = .afterEntry
        }
    }

    var rawValue: String {
        switch self {
        case .beforeEntry:
            return "before_entry"
        case .afterEntry:
            return "after_entry"
        }
    }
}

struct EntryColumn: Identifiable, Equatable {
    let id: String
    var title: String
    var placement: EntryColumnPlacement
    var orderIndex: Int
    var width: Double
}

struct EntryColumnValueKey: Hashable {
    let entryID: Entry.ID
    let columnID: EntryColumn.ID
}
