import CSQLite
import Foundation

final class EntryStore {
    private var db: OpaquePointer?

    convenience init() throws {
        try self.init(databaseURL: Self.databaseURL())
    }

    init(databaseURL: URL) throws {
        try open(path: databaseURL.path)
        try createSchema()
    }

    deinit {
        sqlite3_close(db)
    }

    func loadEntries() throws -> [Entry] {
        let sql = """
        SELECT id, body_plain_text, body_rtf, created_at, updated_at, captured_at, deleted_at
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

            let richTextData: Data?
            if sqlite3_column_type(statement, 2) == SQLITE_NULL {
                richTextData = nil
            } else if let bytes = sqlite3_column_blob(statement, 2) {
                richTextData = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 2)))
            } else {
                richTextData = nil
            }

            let deletedAtValue = sqlite3_column_type(statement, 6) == SQLITE_NULL
                ? nil
                : Date(timeIntervalSince1970: sqlite3_column_double(statement, 6))

            entries.append(Entry(
                id: String(cString: idText),
                body: String(cString: bodyText),
                richTextData: richTextData,
                createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 3)),
                updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 4)),
                capturedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 5)),
                deletedAt: deletedAtValue
            ))
        }

        return entries
    }

    func insert(_ entry: Entry) throws {
        let sql = """
        INSERT INTO entries (id, body_plain_text, body_rtf, created_at, updated_at, captured_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, entry.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, entry.body, -1, SQLITE_TRANSIENT)
        bindRichText(entry.richTextData, to: statement, at: 3)
        sqlite3_bind_double(statement, 4, entry.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 5, entry.updatedAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 6, entry.capturedAt.timeIntervalSince1970)
        if let deletedAt = entry.deletedAt {
            sqlite3_bind_double(statement, 7, deletedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        try step(statement)
    }

    func update(_ entry: Entry) throws {
        let sql = """
        UPDATE entries
        SET body_plain_text = ?, body_rtf = ?, updated_at = ?, deleted_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, entry.body, -1, SQLITE_TRANSIENT)
        bindRichText(entry.richTextData, to: statement, at: 2)
        sqlite3_bind_double(statement, 3, entry.updatedAt.timeIntervalSince1970)
        if let deletedAt = entry.deletedAt {
            sqlite3_bind_double(statement, 4, deletedAt.timeIntervalSince1970)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_text(statement, 5, entry.id, -1, SQLITE_TRANSIENT)

        try step(statement)
    }

    func loadColumns() throws -> [EntryColumn] {
        let sql = """
        SELECT id, title, placement, order_index, width
        FROM entry_columns
        WHERE deleted_at IS NULL
        ORDER BY order_index ASC, created_at ASC;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var columns: [EntryColumn] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idText = sqlite3_column_text(statement, 0),
                let titleText = sqlite3_column_text(statement, 1),
                let placementText = sqlite3_column_text(statement, 2)
            else { continue }

            columns.append(EntryColumn(
                id: String(cString: idText),
                title: String(cString: titleText),
                placement: EntryColumnPlacement(rawValue: String(cString: placementText)),
                orderIndex: Int(sqlite3_column_int(statement, 3)),
                width: sqlite3_column_double(statement, 4)
            ))
        }

        return columns
    }

    func insertColumn(_ column: EntryColumn, createdAt: Date = Date()) throws {
        let sql = """
        INSERT INTO entry_columns (id, title, placement, order_index, width, created_at, updated_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, NULL);
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, column.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, column.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, column.placement.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, Int32(column.orderIndex))
        sqlite3_bind_double(statement, 5, column.width)
        sqlite3_bind_double(statement, 6, createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 7, createdAt.timeIntervalSince1970)

        try step(statement)
    }

    func updateColumnWidth(columnID: EntryColumn.ID, width: Double, updatedAt: Date = Date()) throws {
        let sql = """
        UPDATE entry_columns
        SET width = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, width)
        sqlite3_bind_double(statement, 2, updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, columnID, -1, SQLITE_TRANSIENT)

        try step(statement)
    }

    func updateColumnOrder(_ columns: [EntryColumn], updatedAt: Date = Date()) throws {
        let sql = """
        UPDATE entry_columns
        SET placement = ?, order_index = ?, updated_at = ?
        WHERE id = ?;
        """
        for column in columns {
            var statement: OpaquePointer?
            try prepare(sql, statement: &statement)
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, column.placement.rawValue, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 2, Int32(column.orderIndex))
            sqlite3_bind_double(statement, 3, updatedAt.timeIntervalSince1970)
            sqlite3_bind_text(statement, 4, column.id, -1, SQLITE_TRANSIENT)

            try step(statement)
        }
    }

    func loadColumnValues() throws -> [EntryColumnValueKey: String] {
        let sql = """
        SELECT entry_id, column_id, value_text
        FROM entry_column_values;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var values: [EntryColumnValueKey: String] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let entryIDText = sqlite3_column_text(statement, 0),
                let columnIDText = sqlite3_column_text(statement, 1),
                let valueText = sqlite3_column_text(statement, 2)
            else { continue }

            values[EntryColumnValueKey(
                entryID: String(cString: entryIDText),
                columnID: String(cString: columnIDText)
            )] = String(cString: valueText)
        }

        return values
    }

    func upsertColumnValue(entryID: Entry.ID, columnID: EntryColumn.ID, value: String, updatedAt: Date = Date()) throws {
        let sql = """
        INSERT INTO entry_column_values (entry_id, column_id, value_text, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(entry_id, column_id) DO UPDATE SET
            value_text = excluded.value_text,
            updated_at = excluded.updated_at;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, entryID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, columnID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, value, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 4, updatedAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 5, updatedAt.timeIntervalSince1970)

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
            body_rtf BLOB,
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
        if try !columnExists("body_rtf", in: "entries") {
            try execute("ALTER TABLE entries ADD COLUMN body_rtf BLOB;")
        }
        try execute("""
        CREATE TABLE IF NOT EXISTS entry_columns (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            placement TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            width REAL NOT NULL DEFAULT 120,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        """)
        if try !columnExists("width", in: "entry_columns") {
            try execute("ALTER TABLE entry_columns ADD COLUMN width REAL NOT NULL DEFAULT 120;")
        }
        try execute("""
        CREATE INDEX IF NOT EXISTS idx_entry_columns_order
        ON entry_columns (deleted_at, order_index, created_at);
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS entry_column_values (
            entry_id TEXT NOT NULL,
            column_id TEXT NOT NULL,
            value_text TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            PRIMARY KEY (entry_id, column_id),
            FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
            FOREIGN KEY (column_id) REFERENCES entry_columns(id) ON DELETE CASCADE
        );
        """)
    }

    private func bindRichText(_ data: Data?, to statement: OpaquePointer?, at index: Int32) {
        guard let data else {
            sqlite3_bind_null(statement, index)
            return
        }

        _ = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, index, bytes.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    private func columnExists(_ column: String, in table: String) throws -> Bool {
        let sql = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let nameText = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: nameText) == column {
                return true
            }
        }

        return false
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
