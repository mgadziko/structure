import Foundation

enum EntrySortColumn: Equatable {
    case created
    case body
    case userColumn(String)

    init(kind: String?, columnID: String?) {
        switch kind {
        case "created":
            self = .created
        case "body":
            self = .body
        case "user_column":
            if let columnID {
                self = .userColumn(columnID)
            } else {
                self = .created
            }
        default:
            self = .created
        }
    }

    var storageKind: String {
        switch self {
        case .created:
            return "created"
        case .body:
            return "body"
        case .userColumn:
            return "user_column"
        }
    }

    var storageColumnID: String? {
        switch self {
        case .created, .body:
            return nil
        case .userColumn(let id):
            return id
        }
    }
}

enum EntrySortDirection: Equatable {
    case ascending
    case descending

    init(rawValue: String?) {
        switch rawValue {
        case "descending":
            self = .descending
        default:
            self = .ascending
        }
    }

    var rawValue: String {
        switch self {
        case .ascending:
            return "ascending"
        case .descending:
            return "descending"
        }
    }

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

struct EntrySort: Equatable {
    var column: EntrySortColumn? = .created
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
