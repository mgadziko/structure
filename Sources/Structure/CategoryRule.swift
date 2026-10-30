import Foundation

struct CategoryRule: Identifiable, Equatable {
    let id: String
    var targetColumnDefinitionID: String
    var categoryName: String
    var criteria: [CategoryRuleCriterion]
    var createdAt: Date
    var updatedAt: Date
}

struct CategoryRuleCriterion: Identifiable, Equatable {
    let id: String
    var sourceColumnDefinitionID: String
    var value: String

    init(id: String = UUID().uuidString, sourceColumnDefinitionID: String, value: String) {
        self.id = id
        self.sourceColumnDefinitionID = sourceColumnDefinitionID
        self.value = value
    }

    var normalizedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct CategoryRuleSummary: Identifiable, Equatable {
    let id: CategoryRule.ID
    var targetColumnTitle: String
    var categoryName: String
    var criteriaText: String
    var updatedAt: Date
}
