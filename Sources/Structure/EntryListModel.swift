import Foundation
import SwiftUI

@MainActor
final class EntryListModel: ObservableObject {
    @Published private(set) var entries: [Entry] = []
    @Published var currentEntryID: String?
    @Published var errorMessage: String?

    private let store: EntryStore

    init() {
        do {
            store = try EntryStore()
            entries = try store.loadEntries()
            if entries.isEmpty {
                createEntry()
            } else {
                currentEntryID = entries.last?.id
            }
        } catch {
            fatalError("Could not initialize EntryStore: \(error)")
        }
    }

    func createEntry() {
        let now = Date()
        let entry = Entry(
            id: UUID().uuidString,
            body: "",
            createdAt: now,
            updatedAt: now,
            capturedAt: now,
            deletedAt: nil
        )
        entries.append(entry)
        currentEntryID = entry.id
        persistInsert(entry)
    }

    func updateBody(for id: Entry.ID, body: String) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].body = body
        entries[index].updatedAt = Date()
        persistUpdate(entries[index])
    }

    private func persistInsert(_ entry: Entry) {
        do {
            try store.insert(entry)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func persistUpdate(_ entry: Entry) {
        do {
            try store.update(entry)
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
