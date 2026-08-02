import CSQLite
import Foundation
import XCTest
@testable import Structure

final class EntryStoreTests: XCTestCase {
    func testRichTextDataRoundTripsWithPlainText() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let richTextData = Data("rtf payload".utf8)
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = Entry(
            id: "entry-1",
            body: "Hello Structure",
            richTextData: richTextData,
            createdAt: timestamp,
            updatedAt: timestamp,
            capturedAt: timestamp,
            deletedAt: nil
        )

        try store.insert(entry)

        let entries = try store.loadEntries()
        XCTAssertEqual(entries, [entry])
    }

    func testLegacyDatabaseMigratesBodyRTFColumn() throws {
        let databaseURL = try temporaryDatabaseURL()
        try createLegacyDatabase(at: databaseURL)

        let store = try EntryStore(databaseURL: databaseURL)
        let entries = try store.loadEntries()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.body, "Legacy plain text")
        XCTAssertNil(entries.first?.richTextData)
    }

    func testColumnsRoundTrip() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let column = EntryColumn(
            id: "column-1",
            title: "Attribute",
            placement: .afterEntry,
            orderIndex: 3,
            width: 180
        )

        try store.insertColumn(column, createdAt: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(try store.loadColumns(), [column])
    }

    func testDefaultViewSortRoundTrips() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        var expectedSort = EntrySort()
        expectedSort.select(.body)

        try store.updateViewSort(viewID: StructureView.defaultID, sort: expectedSort, updatedAt: Date(timeIntervalSince1970: 10))

        let view = try store.loadDefaultView()
        XCTAssertEqual(view.id, StructureView.defaultID)
        XCTAssertEqual(view.sort, expectedSort)
    }

    func testViewsRoundTripWithCreatedColumnPreference() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 10)
        let view = StructureView(
            id: "view-1",
            title: "New View 1",
            sort: EntrySort(column: .body, direction: .ascending),
            showsCreatedColumn: false,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try store.insertView(view)

        let loaded = try XCTUnwrap(try store.loadView(id: view.id))
        XCTAssertEqual(loaded, view)
        XCTAssertTrue(try store.loadViews().contains(view))
    }

    func testViewTitleUpdatesRoundTrip() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 10)
        let view = StructureView(
            id: "view-1",
            title: "Original",
            sort: EntrySort(column: .body, direction: .ascending),
            showsCreatedColumn: false,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        try store.insertView(view)
        try store.updateViewTitle(viewID: view.id, title: "Renamed", updatedAt: timestamp)

        XCTAssertEqual(try store.loadView(id: view.id)?.title, "Renamed")
    }

    func testLegacyColumnsAttachToDefaultViewWithNoDefinition() throws {
        let databaseURL = try temporaryDatabaseURL()
        try createLegacyColumnDatabase(at: databaseURL)

        let store = try EntryStore(databaseURL: databaseURL)
        let columns = try store.loadColumns()

        XCTAssertEqual(columns, [
            EntryColumn(
                id: "legacy-column",
                viewID: StructureView.defaultID,
                title: "Legacy",
                placement: .afterEntry,
                orderIndex: 0,
                width: 120,
                definition: .none
            )
        ])
    }

    func testColumnOrderUpdatesRoundTrip() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 10)
        let first = EntryColumn(
            id: "column-1",
            title: "First",
            placement: .afterEntry,
            orderIndex: 0,
            width: 120
        )
        let second = EntryColumn(
            id: "column-2",
            title: "Second",
            placement: .afterEntry,
            orderIndex: 1,
            width: 160
        )

        try store.insertColumn(first, createdAt: timestamp)
        try store.insertColumn(second, createdAt: timestamp)

        var reorderedSecond = second
        reorderedSecond.orderIndex = 0
        var reorderedFirst = first
        reorderedFirst.orderIndex = 1
        try store.updateColumnOrder([reorderedSecond, reorderedFirst], updatedAt: timestamp)

        XCTAssertEqual(try store.loadColumns(), [reorderedSecond, reorderedFirst])
    }

    func testColumnWidthUpdatesRoundTrip() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 10)
        var column = EntryColumn(
            id: "column-1",
            title: "Resizable",
            placement: .afterEntry,
            orderIndex: 0,
            width: 120
        )

        try store.insertColumn(column, createdAt: timestamp)
        try store.updateColumnWidth(columnID: column.id, width: 240, updatedAt: timestamp)

        column.width = 240
        XCTAssertEqual(try store.loadColumns(), [column])
    }

    func testColumnTitleUpdatesRoundTrip() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 10)
        var column = EntryColumn(
            id: "column-1",
            title: "Original",
            placement: .afterEntry,
            orderIndex: 0,
            width: 120
        )

        try store.insertColumn(column, createdAt: timestamp)
        try store.updateColumnTitle(columnID: column.id, title: "Renamed", updatedAt: timestamp)

        column.title = "Renamed"
        XCTAssertEqual(try store.loadColumns(), [column])
    }

    func testColumnValuesRoundTrip() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = Entry(
            id: "entry-1",
            body: "Hello Structure",
            richTextData: nil,
            createdAt: timestamp,
            updatedAt: timestamp,
            capturedAt: timestamp,
            deletedAt: nil
        )
        let column = EntryColumn(
            id: "column-1",
            title: "Attribute",
            placement: .afterEntry,
            orderIndex: 0,
            width: 120
        )

        try store.insert(entry)
        try store.insertColumn(column, createdAt: timestamp)
        let richTextData = Data("column rtf payload".utf8)
        try store.upsertColumnValue(
            entryID: entry.id,
            columnID: column.id,
            value: EntryColumnValue(text: "example", richTextData: richTextData),
            updatedAt: timestamp
        )

        XCTAssertEqual(try store.loadColumnValues(), [
            EntryColumnValueKey(entryID: entry.id, columnID: column.id): EntryColumnValue(text: "example", richTextData: richTextData)
        ])

        try store.upsertColumnValue(
            entryID: entry.id,
            columnID: column.id,
            value: EntryColumnValue(text: "updated", richTextData: nil),
            updatedAt: timestamp
        )
        XCTAssertEqual(try store.loadColumnValues(), [
            EntryColumnValueKey(entryID: entry.id, columnID: column.id): EntryColumnValue(text: "updated", richTextData: nil)
        ])
    }

    func testColumnTemplateAndValueCopySupportReusingColumnInNewView() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = Entry(
            id: "entry-1",
            body: "Hello Structure",
            richTextData: nil,
            createdAt: timestamp,
            updatedAt: timestamp,
            capturedAt: timestamp,
            deletedAt: nil
        )
        let sourceColumn = EntryColumn(
            id: "column-source",
            title: "Second Column",
            placement: .afterEntry,
            orderIndex: 0,
            width: 240,
            definition: .attribute
        )
        let targetColumn = EntryColumn(
            id: "column-target",
            viewID: "view-2",
            title: "Second Column",
            placement: .afterEntry,
            orderIndex: 0,
            width: 240,
            definition: .attribute
        )
        let richTextData = Data("copied rtf".utf8)

        try store.insert(entry)
        try store.insertColumn(sourceColumn, createdAt: timestamp)
        try store.upsertColumnValue(
            entryID: entry.id,
            columnID: sourceColumn.id,
            value: EntryColumnValue(text: "existing value", richTextData: richTextData),
            updatedAt: timestamp
        )

        let template = try XCTUnwrap(try store.loadColumnTemplate(named: "second column"))
        XCTAssertEqual(template.title, sourceColumn.title)
        XCTAssertEqual(template.width, sourceColumn.width)
        XCTAssertEqual(template.definition, sourceColumn.definition)
        XCTAssertEqual(template.definitionID, sourceColumn.definitionID)

        try store.insertView(StructureView(
            id: "view-2",
            title: "New View",
            sort: EntrySort(column: .body, direction: .ascending),
            showsCreatedColumn: false,
            createdAt: timestamp,
            updatedAt: timestamp
        ))
        try store.insertColumn(targetColumn, createdAt: timestamp)
        try store.copyColumnValues(from: sourceColumn.id, to: targetColumn.id, updatedAt: timestamp)

        XCTAssertEqual(try store.loadColumnValues()[EntryColumnValueKey(entryID: entry.id, columnID: targetColumn.id)], EntryColumnValue(
            text: "existing value",
            richTextData: richTextData
        ))
    }

    func testSharedColumnDefinitionRevealsValuesInAnotherViewWithoutCopying() throws {
        let store = try EntryStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let entry = Entry(
            id: "entry-1",
            body: "Hello Structure",
            richTextData: nil,
            createdAt: timestamp,
            updatedAt: timestamp,
            capturedAt: timestamp,
            deletedAt: nil
        )
        let sourceColumn = EntryColumn(
            id: "column-source",
            title: "People",
            placement: .afterEntry,
            orderIndex: 0,
            width: 180
        )
        let targetColumn = EntryColumn(
            id: "column-target",
            definitionID: sourceColumn.definitionID,
            viewID: "view-2",
            title: "People",
            placement: .afterEntry,
            orderIndex: 0,
            width: 180
        )

        try store.insert(entry)
        try store.insertColumn(sourceColumn, createdAt: timestamp)
        try store.upsertColumnValue(
            entryID: entry.id,
            columnID: sourceColumn.id,
            value: EntryColumnValue(text: "Sarah", richTextData: nil),
            updatedAt: timestamp
        )
        try store.insertView(StructureView(
            id: "view-2",
            title: "People View",
            sort: EntrySort(column: .body, direction: .ascending),
            showsCreatedColumn: false,
            createdAt: timestamp,
            updatedAt: timestamp
        ))
        try store.insertColumn(targetColumn, createdAt: timestamp)

        XCTAssertEqual(
            try store.loadColumnValues()[EntryColumnValueKey(entryID: entry.id, columnID: targetColumn.id)],
            EntryColumnValue(text: "Sarah", richTextData: nil)
        )
    }

    func testLegacyColumnValuesMigrateRichTextColumn() throws {
        let databaseURL = try temporaryDatabaseURL()
        try createLegacyColumnValueDatabase(at: databaseURL)

        let store = try EntryStore(databaseURL: databaseURL)

        XCTAssertEqual(try store.loadColumnValues(), [
            EntryColumnValueKey(entryID: "entry-1", columnID: "column-1"): EntryColumnValue(text: "legacy value", richTextData: nil)
        ])
    }

    func testLegacyColumnValuesMigrateIntoSharedAssignments() throws {
        let databaseURL = try temporaryDatabaseURL()
        try createLegacyColumnValueDatabase(at: databaseURL)

        let store = try EntryStore(databaseURL: databaseURL)
        let sourceColumn = try XCTUnwrap(try store.loadColumns().first)
        let timestamp = Date(timeIntervalSince1970: 10)
        try store.insertView(StructureView(
            id: "view-2",
            title: "New View",
            sort: EntrySort(column: .body, direction: .ascending),
            showsCreatedColumn: false,
            createdAt: timestamp,
            updatedAt: timestamp
        ))
        let reusedColumn = EntryColumn(
            id: "column-reused",
            definitionID: sourceColumn.definitionID,
            viewID: "view-2",
            title: sourceColumn.title,
            placement: .afterEntry,
            orderIndex: 0,
            width: sourceColumn.width,
            definition: sourceColumn.definition
        )

        try store.insertColumn(reusedColumn, createdAt: timestamp)

        XCTAssertEqual(
            try store.loadColumnValues()[EntryColumnValueKey(entryID: "entry-1", columnID: reusedColumn.id)],
            EntryColumnValue(text: "legacy value", richTextData: nil)
        )
    }

    private func temporaryDatabaseURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("Structure.sqlite")
    }

    private func createLegacyDatabase(at url: URL) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        try execute("""
        CREATE TABLE entries (
            id TEXT PRIMARY KEY NOT NULL,
            body_plain_text TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            captured_at REAL NOT NULL,
            deleted_at REAL
        );
        """, db: db)
        try execute("""
        INSERT INTO entries (id, body_plain_text, created_at, updated_at, captured_at, deleted_at)
        VALUES ('legacy-1', 'Legacy plain text', 1, 1, 1, NULL);
        """, db: db)
    }

    private func createLegacyColumnDatabase(at url: URL) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        try execute("""
        CREATE TABLE entries (
            id TEXT PRIMARY KEY NOT NULL,
            body_plain_text TEXT NOT NULL,
            body_rtf BLOB,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            captured_at REAL NOT NULL,
            deleted_at REAL
        );
        """, db: db)
        try execute("""
        CREATE TABLE entry_columns (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            placement TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            width REAL NOT NULL DEFAULT 120,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        """, db: db)
        try execute("""
        INSERT INTO entry_columns (id, title, placement, order_index, width, created_at, updated_at, deleted_at)
        VALUES ('legacy-column', 'Legacy', 'after_entry', 0, 120, 1, 1, NULL);
        """, db: db)
    }

    private func createLegacyColumnValueDatabase(at url: URL) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        try execute("""
        CREATE TABLE entries (
            id TEXT PRIMARY KEY NOT NULL,
            body_plain_text TEXT NOT NULL,
            body_rtf BLOB,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            captured_at REAL NOT NULL,
            deleted_at REAL
        );
        """, db: db)
        try execute("""
        CREATE TABLE entry_columns (
            id TEXT PRIMARY KEY NOT NULL,
            view_id TEXT NOT NULL DEFAULT 'default',
            title TEXT NOT NULL,
            placement TEXT NOT NULL,
            order_index INTEGER NOT NULL,
            width REAL NOT NULL DEFAULT 120,
            definition_kind TEXT NOT NULL DEFAULT 'none',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            deleted_at REAL
        );
        """, db: db)
        try execute("""
        CREATE TABLE entry_column_values (
            entry_id TEXT NOT NULL,
            column_id TEXT NOT NULL,
            value_text TEXT NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            PRIMARY KEY (entry_id, column_id)
        );
        """, db: db)
        try execute("""
        INSERT INTO entries (id, body_plain_text, body_rtf, created_at, updated_at, captured_at, deleted_at)
        VALUES ('entry-1', 'Entry', NULL, 1, 1, 1, NULL);
        """, db: db)
        try execute("""
        INSERT INTO entry_columns (id, view_id, title, placement, order_index, width, definition_kind, created_at, updated_at, deleted_at)
        VALUES ('column-1', 'default', 'Legacy Column', 'after_entry', 0, 120, 'none', 1, 1, NULL);
        """, db: db)
        try execute("""
        INSERT INTO entry_column_values (entry_id, column_id, value_text, created_at, updated_at)
        VALUES ('entry-1', 'column-1', 'legacy value', 1, 1);
        """, db: db)
    }

    private func execute(_ sql: String, db: OpaquePointer?) throws {
        if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
            let message = sqlite3_errmsg(db).map { String(cString: $0) } ?? "Unknown SQLite error"
            XCTFail(message)
        }
    }
}
