import Foundation
import XCTest
@testable import Structure

final class OneNoteHTMLImporterTests: XCTestCase {
    func testParsesPageBlocksAndPreservesOneNoteContext() throws {
        let html = """
        <!DOCTYPE html>
        <html><head><title>Citadel of Glass</title></head><body>
        <h1>Arrival</h1><p>The party enters at dusk.</p>
        <ul><li>Guard captain is missing</li></ul>
        <table><tr><th>NPC</th><th>Role</th></tr><tr><td><b>Maris</b></td><td>Guide</td></tr></table>
        <img alt="Map of the citadel" />
        </body></html>
        """

        let blocks = OneNotePageHTMLParser.parse(
            data: try XCTUnwrap(html.data(using: .utf8)),
            fallbackPageName: "fallback",
            notebook: "Worlorn",
            section: "Session Notes"
        )

        XCTAssertEqual(blocks.map(\.body), [
            "Arrival",
            "The party enters at dusk.",
            "- Guard captain is missing",
            "NPC | Role",
            "Maris | Guide",
            "[Image: Map of the citadel]"
        ])
        XCTAssertEqual(blocks.map(\.blockType), ["Heading", "Paragraph", "List Item", "Table Row", "Table Row", "Image"])
        XCTAssertEqual(blocks.map(\.pageName), Array(repeating: "Citadel of Glass", count: 6))
        XCTAssertEqual(blocks.map(\.notebook), Array(repeating: "Worlorn", count: 6))
        XCTAssertEqual(blocks.map(\.section), Array(repeating: "Session Notes", count: 6))
        XCTAssertEqual(blocks.map(\.blockOrder), [1, 2, 3, 4, 5, 6])
    }

    func testRejectsNativeOneNotePackages() throws {
        let url = URL(fileURLWithPath: "/tmp/notes.onepkg")
        XCTAssertThrowsError(try OneNoteHTMLImporter.load(from: url)) { error in
            XCTAssertEqual(error as? OneNoteHTMLImportError, .unsupportedNativeNotebook)
        }
    }
}
