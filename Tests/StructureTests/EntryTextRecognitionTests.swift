import XCTest
@testable import Structure

final class EntryTextRecognitionTests: XCTestCase {
    func testMatchesIgnoringCapitalization() {
        XCTAssertTrue(EntryTextRecognition.contains("Dessert", in: "Have cake off the dessert menu"))
        XCTAssertTrue(EntryTextRecognition.contains("dessert", in: "Have cake off the Dessert menu"))
        XCTAssertTrue(EntryTextRecognition.contains("DESSERT", in: "Have cake off the dessert menu"))
    }

    func testDoesNotMatchInsideLongerWord() {
        XCTAssertFalse(EntryTextRecognition.contains("Ann", in: "Annual budget review"))
        XCTAssertFalse(EntryTextRecognition.contains("dessert", in: "desserted island notes"))
    }

    func testDoesNotMatchDifferentWordWithSameFirstLetter() {
        XCTAssertFalse(EntryTextRecognition.contains("Sighere", in: "Call Sarah about the billing cycle"))
    }

    func testDoesNotRecognizeSingleLetterWords() {
        XCTAssertFalse(EntryTextRecognition.contains("A", in: "Give me a red rose and a purple heart."))
        XCTAssertNil(EntryTextRecognition.firstMatchLocation(of: "A", in: "I received a purple heart."))
    }

    func testReportsWholeWordMatchLocation() {
        XCTAssertEqual(
            EntryTextRecognition.firstMatchLocation(of: "Red", in: "Give me a red rose and a purple heart."),
            10
        )
        XCTAssertEqual(
            EntryTextRecognition.firstMatchLocation(of: "Purple", in: "Give me a red rose and a purple heart."),
            25
        )
    }
}
