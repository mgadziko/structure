import Foundation

enum EntryColumnDefinition: String {
    case none
    case category
    case attribute
}

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
    var viewID: StructureView.ID
    var title: String
    var placement: EntryColumnPlacement
    var orderIndex: Int
    var width: Double
    var definition: EntryColumnDefinition

    init(
        id: String,
        viewID: StructureView.ID = StructureView.defaultID,
        title: String,
        placement: EntryColumnPlacement,
        orderIndex: Int,
        width: Double,
        definition: EntryColumnDefinition = .none
    ) {
        self.id = id
        self.viewID = viewID
        self.title = title
        self.placement = placement
        self.orderIndex = orderIndex
        self.width = width
        self.definition = definition
    }
}

struct EntryColumnValueKey: Hashable {
    let entryID: Entry.ID
    let columnID: EntryColumn.ID
}

struct EntryColumnValue: Equatable {
    var text: String
    var richTextData: Data?

    static let empty = EntryColumnValue(text: "", richTextData: nil)
}
