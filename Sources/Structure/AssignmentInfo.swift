import Foundation

enum AssignmentSource: String, Equatable {
    case explicit
    case categoryRule = "category_rule"
    case entryTextRecognition = "entry_text_recognition"
    case other

    init(storageValue: String) {
        switch storageValue {
        case "column_edit":
            self = .explicit
        case "category_rule":
            self = .categoryRule
        case "entry_text_recognition":
            self = .entryTextRecognition
        default:
            self = .other
        }
    }

    var displayName: String {
        switch self {
        case .explicit:
            return "Explicit"
        case .categoryRule:
            return "Category Rule"
        case .entryTextRecognition:
            return "Entry Text Recognition"
        case .other:
            return "Other"
        }
    }
}

struct AssignmentInfo: Equatable {
    var source: AssignmentSource
    var sourceDetail: String?

    var isRuleCreated: Bool {
        source == .categoryRule || source == .entryTextRecognition
    }
}
