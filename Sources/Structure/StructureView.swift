import Foundation

struct StructureView: Identifiable, Equatable {
    static let defaultID = "default"

    let id: String
    var title: String
    var sort: EntrySort
    var showsCreatedColumn: Bool
    var createdAt: Date
    var updatedAt: Date
}
