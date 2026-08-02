import Foundation

struct Entry: Identifiable, Equatable {
    let id: String
    var body: String
    var bodyMarkdown: String? = nil
    var richTextData: Data?
    let createdAt: Date
    var updatedAt: Date
    let capturedAt: Date
    var deletedAt: Date?

    var displayDate: String {
        Entry.dateFormatter.string(from: capturedAt)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
