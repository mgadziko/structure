import XCTest
@testable import Structure

final class CriteriaMatcherTests: XCTestCase {
    func testMatchesAnyValueWithinSameKeyAndAllKeysAcrossGroups() throws {
        let criteria = [
            TestCriterion(key: "Project", normalizedValue: "proposal"),
            TestCriterion(key: "Project", normalizedValue: "budget"),
            TestCriterion(key: "Standing", normalizedValue: "active")
        ]

        XCTAssertTrue(CriteriaMatcher.matches(
            criteria: criteria,
            key: \.key,
            normalizedValue: \.normalizedValue
        ) { key in
            ["Project": "Budget", "Standing": "Active"][key]
        })

        XCTAssertFalse(CriteriaMatcher.matches(
            criteria: criteria,
            key: \.key,
            normalizedValue: \.normalizedValue
        ) { key in
            ["Project": "Pledge", "Standing": "Active"][key]
        })

        XCTAssertFalse(CriteriaMatcher.matches(
            criteria: criteria,
            key: \.key,
            normalizedValue: \.normalizedValue
        ) { key in
            ["Project": "Proposal", "Standing": "Inactive"][key]
        })
    }

    private struct TestCriterion {
        var key: String
        var normalizedValue: String
    }
}
