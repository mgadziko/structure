import Foundation

enum CriteriaMatcher {
    static func matches<Key: Hashable, Criterion>(
        criteria: [Criterion],
        key: (Criterion) -> Key,
        normalizedValue: (Criterion) -> String,
        valueForKey: (Key) throws -> String?
    ) rethrows -> Bool {
        guard !criteria.isEmpty else { return false }

        let groupedCriteria = Dictionary(grouping: criteria, by: key)
        for (criterionKey, criteriaForKey) in groupedCriteria {
            guard let candidateValue = try valueForKey(criterionKey) else { return false }
            let normalizedCandidate = candidateValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            guard !normalizedCandidate.isEmpty else { return false }

            let keyMatches = criteriaForKey.contains { criterion in
                normalizedValue(criterion) == normalizedCandidate
            }
            guard keyMatches else { return false }
        }

        return true
    }
}
