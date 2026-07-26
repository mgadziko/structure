import CSQLite
import Foundation
import SwiftUI
import AppKit

struct Entry: Identifiable, Equatable {
    let id: String
    var body: String
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

enum StructureError: Error, CustomStringConvertible {
    case sqlite(String)
    case storagePathUnavailable

    var description: String {
        switch self {
        case .sqlite(let message):
            return message
        case .storagePathUnavailable:
            return "Could not create the Structure application support folder."
        }
    }
}

final class EntryStore {
    private var db: OpaquePointer?

    init() throws {
        let path = try Self.databaseURL()
        try open(path: path.path)
        try createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    func loadEntries() throws -> [Entry] {
        let sql = """
        SELECT id, body_plain_text, created_at, updated_at, captured_at, deleted_at
        FROM entries
        WHERE deleted_at IS NULL
        ORDER BY captured_at ASC, created_at ASC;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var entries: [Entry] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idText = sqlite3_column_text(statement, 0),
                let bodyText = sqlite3_column_text(statement, 1)
            else { continue }

            let deletedAtValue = sqlite3_column_type(statement, 5) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(statement, 5))

            entries.append(Entry(
                id: String(cString: idText),
                body: String(cString: bodyText),
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                capturedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                deletedAt: deletedAtValue
            ))
        }

        return entries
    }

    func insert(_ entry: Entry) throws {
        let sql = """
        INSERT INTO entries (id, body_plain_text, created_at, updated_at, captured_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, entry.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, entry.body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 3, entry.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 4, entry.updatedAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 5, entry.capturedAt.timeIntervalSince1970)
        if let deletedAt = entry.deletedAt {
            sqlite3_bind_double(statement, 6, deletedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        try step(statement)
    }

    func update(_ entry: Entry) throws {
        let sql = """
        UPDATE entries
        SET body_plain_text = ?, updated_at = ?, deleted_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, entry.body, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, entry.updatedAt.timeIntervalSince1970)
        if let deletedAt = entry.deletedAt {
            sqlite3_bind_double(statement, 3, deletedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 3)
        }
        sqlite3_bind_text(statement, 4, entry.id, -1, SQLITE_TRANSIENT)

        try step(statement)
    }

    private func open(path: String) throws {
        if sqlite3_open(path, &db) != SQLITE_OK {
            throw StructureError.sqlite(lastError)
        }
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
    }

    private func createSchema() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS entries (
            id TEXT PRIMARY KEY NOT NULL,
            body_plain_text TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            captured_at REAL NOT NULL,
            deleted_at REAL
        );
        """)
        try execute("""
        CREATE INDEX IF NOT EXISTS idx_entries_capture_order
        ON entries (deleted_at, captured_at, created_at);
        """)
    }

    private func execute(_ sql: String) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            throw StructureError.sqlite(lastError)
        }
    }

    private func prepare(_ sql: String, statement: inout OpaquePointer?) throws {
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) != SQLITE_OK {
            throw StructureError.sqlite(lastError)
        }
    }

    private func step(_ statement: OpaquePointer?) throws {
        if sqlite3_step(statement) != SQLITE_DONE {
            throw StructureError.sqlite(lastError)
        }
    }

    private var lastError: String {
        if let message = sqlite3_errmsg(db) {
            return String(cString: message)
        }
        return "Unknown SQLite error."
    }

    private static func databaseURL() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let directory = base?.appendingPathComponent("Structure", isDirectory: true) else {
            throw StructureError.storagePathUnavailable
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Structure.sqlite")
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

struct EntryStreamView: View {
    @ObservedObject var model: EntryListModel
    @FocusState private var focusedEntryID: Entry.ID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ForEach(model.entries) { entry in
                        EntryEditor(
                            entry: entry,
                            text: binding(for: entry.id),
                            focusedEntryID: $focusedEntryID
                        )
                        .id(entry.id)
                    }
                }
                .padding(.horizontal, 38)
                .padding(.vertical, 32)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .onAppear {
                focusCurrentEntry(proxy: proxy, animated: false)
            }
            .onChange(of: model.currentEntryID) { id in
                focusCurrentEntry(proxy: proxy, animated: id != nil)
            }
        }
        .overlay(alignment: .bottomLeading) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.regularMaterial)
                    .padding()
            }
        }
    }

    private func binding(for id: Entry.ID) -> Binding<String> {
        Binding(
            get: { model.entries.first(where: { $0.id == id })?.body ?? "" },
            set: { model.updateBody(for: id, body: $0) }
        )
    }

    private func focusCurrentEntry(proxy: ScrollViewProxy, animated: Bool) {
        guard let id = model.currentEntryID else { return }
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(id, anchor: .bottom)
            }
            focusedEntryID = id
        }
    }
}

struct EntryEditor: View {
    let entry: Entry
    @Binding var text: String
    var focusedEntryID: FocusState<Entry.ID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.displayDate)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .focused(focusedEntryID, equals: entry.id)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 96)
                .padding(.horizontal, -5)
                .accessibilityLabel("Entry created \(entry.displayDate)")
        }
    }
}

final class StructureAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            openStructureWindow()
        }
        return true
    }
}

func openStructureWindow() {
    NSApp.activate(ignoringOtherApps: true)
    NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
}

@main
struct StructureApp: App {
    @NSApplicationDelegateAdaptor(StructureAppDelegate.self) private var appDelegate
    @StateObject private var model = EntryListModel()

    var body: some Scene {
        WindowGroup("Structure") {
            EntryStreamView(model: model)
                .frame(minWidth: 620, minHeight: 520)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("New Window") {
                    openStructureWindow()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("New Entry") {
                    model.createEntry()
                }
                .keyboardShortcut("e", modifiers: [.command])
            }
        }
    }
}
