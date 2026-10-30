import Foundation

enum EntryTextRecognition {
    static func contains(_ candidateValue: String, in entryText: String) -> Bool {
        firstMatchLocation(of: candidateValue, in: entryText) != nil
    }

    static func firstMatchLocation(of candidateValue: String, in entryText: String) -> Int? {
        let trimmedValue = candidateValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isEligibleCandidate(trimmedValue) else { return nil }

        let escapedValue = NSRegularExpression.escapedPattern(for: trimmedValue)
        let pattern = #"(?<![\p{L}\p{N}])"# + escapedValue + #"(?![\p{L}\p{N}])"#
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }

        let range = NSRange(entryText.startIndex..<entryText.endIndex, in: entryText)
        return expression.firstMatch(in: entryText, range: range)?.range.location
    }

    private static func isEligibleCandidate(_ candidateValue: String) -> Bool {
        let scalars = candidateValue.unicodeScalars
        let letterCount = scalars.filter { CharacterSet.letters.contains($0) }.count
        let numberCount = scalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        guard letterCount + numberCount > 0 else { return false }
        return !(letterCount == 1 && numberCount == 0)
    }
}
