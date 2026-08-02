import Foundation

enum EntryColumnDefinition: String, CaseIterable, Identifiable {
    case none
    case category
    case textAttribute = "text_attribute"
    case date
    case number
    case state

    var id: String { rawValue }

    init(storageValue: String?) {
        switch storageValue {
        case "attribute":
            self = .textAttribute
        default:
            self = storageValue.flatMap { EntryColumnDefinition(rawValue: $0) } ?? .none
        }
    }

    var displayName: String {
        switch self {
        case .none:
            return "Undefined"
        case .category:
            return "Category"
        case .textAttribute:
            return "Text Attribute"
        case .date:
            return "Date"
        case .number:
            return "Number"
        case .state:
            return "State"
        }
    }

    var inspectorDescription: String {
        switch self {
        case .none:
            return "Accepts plain values without assigning a formal meaning."
        case .category:
            return "Treats values as category-like assignments that can be reused across Views."
        case .textAttribute:
            return "Stores descriptive text values. Detailed behavior comes later."
        case .date:
            return "Stores date values. Parsing and date states come later."
        case .number:
            return "Stores numeric values. Calculations come later."
        case .state:
            return "Stores changeable state values. History comes later."
        }
    }
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
    var definitionID: String
    var viewID: StructureView.ID
    var title: String
    var placement: EntryColumnPlacement
    var orderIndex: Int
    var width: Double
    var definition: EntryColumnDefinition

    init(
        id: String,
        definitionID: String? = nil,
        viewID: StructureView.ID = StructureView.defaultID,
        title: String,
        placement: EntryColumnPlacement,
        orderIndex: Int,
        width: Double,
        definition: EntryColumnDefinition = .none
    ) {
        self.id = id
        self.definitionID = definitionID ?? Self.defaultDefinitionID(for: title)
        self.viewID = viewID
        self.title = title
        self.placement = placement
        self.orderIndex = orderIndex
        self.width = width
        self.definition = definition
    }

    static func defaultDefinitionID(for title: String) -> String {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let slug = normalizedTitle.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "-"
        }
        .joined()
        .split(separator: "-")
        .joined(separator: "-")

        return "column-definition-\(slug.isEmpty ? "untitled" : slug)"
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
