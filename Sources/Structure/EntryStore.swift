import CSQLite
import Foundation

final class EntryStore {
    private var db: OpaquePointer?
    static var defaultDatabaseURL: URL {
        get throws {
            try databaseURL()
        }
    }

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

    func loadDefaultView() throws -> StructureView {
        try ensureDefaultViewExists()
        guard let view = try loadView(id: StructureView.defaultID) else {
            throw StructureError.sqlite("Default view was not available.")
        }
        return view
    }

    func loadViews() throws -> [StructureView] {
        let sql = """
        SELECT id, title, sort_column_kind, sort_column_id, sort_direction, shows_created_column, created_at, updated_at
        FROM structure_views
        WHERE deleted_at IS NULL
        ORDER BY title COLLATE NOCASE ASC, created_at ASC;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var views: [StructureView] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            views.append(view(from: statement))
        }

        return views
    }

    func loadView(id: StructureView.ID) throws -> StructureView? {
        let sql = """
        SELECT id, title, sort_column_kind, sort_column_id, sort_direction, shows_created_column, created_at, updated_at
        FROM structure_views
        WHERE id = ? AND deleted_at IS NULL;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        return view(from: statement)
    }

    func insertView(_ view: StructureView) throws {
        let sql = """
        INSERT INTO structure_views (
            id, title, sort_column_kind, sort_column_id, sort_direction, shows_created_column, created_at, updated_at, deleted_at
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL);
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        bindView(view, to: statement)
        try step(statement)
    }

    func updateViewTitle(viewID: StructureView.ID, title: String, updatedAt: Date = Date()) throws {
        let sql = """
        UPDATE structure_views
        SET title = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 2, updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 3, viewID, -1, SQLITE_TRANSIENT)

        try step(statement)
    }

    func loadAllColumnNames() throws -> [String] {
        let sql = """
        SELECT DISTINCT title
        FROM entry_columns
        WHERE deleted_at IS NULL
        ORDER BY title COLLATE NOCASE ASC;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        var names: [String] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let titleText = sqlite3_column_text(statement, 0) else { continue }
            names.append(String(cString: titleText))
        }

        return names
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

    func loadColumns(viewID: StructureView.ID = StructureView.defaultID) throws -> [EntryColumn] {
        let sql = """
        SELECT id, view_id, title, placement, order_index, width, definition_kind
        FROM entry_columns
        WHERE view_id = ? AND deleted_at IS NULL
        ORDER BY order_index ASC, created_at ASC;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, viewID, -1, SQLITE_TRANSIENT)

        var columns: [EntryColumn] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idText = sqlite3_column_text(statement, 0),
                let viewIDText = sqlite3_column_text(statement, 1),
                let titleText = sqlite3_column_text(statement, 2),
                let placementText = sqlite3_column_text(statement, 3)
            else { continue }

            let definitionText = sqlite3_column_text(statement, 6).map { String(cString: $0) } ?? EntryColumnDefinition.none.rawValue
            columns.append(EntryColumn(
                id: String(cString: idText),
                viewID: String(cString: viewIDText),
                title: String(cString: titleText),
                placement: EntryColumnPlacement(rawValue: String(cString: placementText)),
                orderIndex: Int(sqlite3_column_int(statement, 4)),
                width: sqlite3_column_double(statement, 5),
                definition: EntryColumnDefinition(rawValue: definitionText) ?? .none
            ))
        }

        return columns
    }

    func insertColumn(_ column: EntryColumn, createdAt: Date = Date()) throws {
        let sql = """
        INSERT INTO entry_columns (id, view_id, title, placement, order_index, width, definition_kind, created_at, updated_at, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NULL);
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, column.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, column.viewID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, column.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, column.placement.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 5, Int32(column.orderIndex))
        sqlite3_bind_double(statement, 6, column.width)
        sqlite3_bind_text(statement, 7, column.definition.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 8, createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 9, createdAt.timeIntervalSince1970)

        try step(statement)
    }

    func updateViewSort(viewID: StructureView.ID, sort: EntrySort, updatedAt: Date = Date()) throws {
        let sql = """
        UPDATE structure_views
        SET sort_column_kind = ?, sort_column_id = ?, sort_direction = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, sort.column?.storageKind, -1, SQLITE_TRANSIENT)
        if let columnID = sort.column?.storageColumnID {
            sqlite3_bind_text(statement, 2, columnID, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 2)
        }
        sqlite3_bind_text(statement, 3, sort.direction.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 4, updatedAt.timeIntervalSince1970)
        sqlite3_bind_text(statement, 5, viewID, -1, SQLITE_TRANSIENT)

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

    func updateColumnTitle(columnID: EntryColumn.ID, title: String, updatedAt: Date = Date()) throws {
        let sql = """
        UPDATE entry_columns
        SET title = ?, updated_at = ?
        WHERE id = ?;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, title, -1, SQLITE_TRANSIENT)
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
        CREATE TABLE IF NOT EXISTS structure_views (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            sort_column_kind TEXT,
            sort_column_id TEXT,
            sort_direction TEXT NOT NULL DEFAULT 'ascending',
            shows_created_column INTEGER NOT NULL DEFAULT 1,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        """)
        if try !columnExists("shows_created_column", in: "structure_views") {
            try execute("ALTER TABLE structure_views ADD COLUMN shows_created_column INTEGER NOT NULL DEFAULT 1;")
        }
        try execute("""
        CREATE TABLE IF NOT EXISTS entry_columns (
            id TEXT PRIMARY KEY NOT NULL,
            view_id TEXT NOT NULL DEFAULT 'default',
            title TEXT NOT NULL,
            placement TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            width REAL NOT NULL DEFAULT 120,
            definition_kind TEXT NOT NULL DEFAULT 'none',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL,
            FOREIGN KEY (view_id) REFERENCES structure_views(id) ON DELETE CASCADE
        );
        """)
        try ensureDefaultViewExists()
        if try !columnExists("view_id", in: "entry_columns") {
            try execute("ALTER TABLE entry_columns ADD COLUMN view_id TEXT NOT NULL DEFAULT 'default';")
        }
        if try !columnExists("width", in: "entry_columns") {
            try execute("ALTER TABLE entry_columns ADD COLUMN width REAL NOT NULL DEFAULT 120;")
        }
        if try !columnExists("definition_kind", in: "entry_columns") {
            try execute("ALTER TABLE entry_columns ADD COLUMN definition_kind TEXT NOT NULL DEFAULT 'none';")
        }
        try execute("UPDATE entry_columns SET view_id = 'default' WHERE view_id IS NULL OR view_id = '';")
        try execute("UPDATE entry_columns SET definition_kind = 'none' WHERE definition_kind IS NULL OR definition_kind = '';")
        try execute("""
        CREATE INDEX IF NOT EXISTS idx_entry_columns_order
        ON entry_columns (view_id, deleted_at, order_index, created_at);
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

    private func ensureDefaultViewExists() throws {
        let now = Date().timeIntervalSince1970
        let sql = """
        INSERT INTO structure_views (
            id, title, sort_column_kind, sort_column_id, sort_direction, shows_created_column, created_at, updated_at, deleted_at
        )
        VALUES ('default', 'All Entries', 'created', NULL, 'ascending', 1, ?, ?, NULL)
        ON CONFLICT(id) DO NOTHING;
        """
        var statement: OpaquePointer?
        try prepare(sql, statement: &statement)
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_double(statement, 1, now)
        sqlite3_bind_double(statement, 2, now)

        try step(statement)
    }

    private func view(from statement: OpaquePointer?) -> StructureView {
        let idText = sqlite3_column_text(statement, 0)!
        let titleText = sqlite3_column_text(statement, 1)!
        let sortKind = sqlite3_column_text(statement, 2).map { String(cString: $0) }
        let sortColumnID = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let sortDirection = sqlite3_column_text(statement, 4).map { String(cString: $0) }

        return StructureView(
            id: String(cString: idText),
            title: String(cString: titleText),
            sort: EntrySort(
                column: EntrySortColumn(kind: sortKind, columnID: sortColumnID),
                direction: EntrySortDirection(rawValue: sortDirection)
            ),
            showsCreatedColumn: sqlite3_column_int(statement, 5) != 0,
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 6)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 7))
        )
    }

    private func bindView(_ view: StructureView, to statement: OpaquePointer?) {
        sqlite3_bind_text(statement, 1, view.id, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, view.title, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, view.sort.column?.storageKind, -1, SQLITE_TRANSIENT)
        if let columnID = view.sort.column?.storageColumnID {
            sqlite3_bind_text(statement, 4, columnID, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 4)
        }
        sqlite3_bind_text(statement, 5, view.sort.direction.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 6, view.showsCreatedColumn ? 1 : 0)
        sqlite3_bind_double(statement, 7, view.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(statement, 8, view.updatedAt.timeIntervalSince1970)
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
