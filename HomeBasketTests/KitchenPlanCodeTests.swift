
import XCTest
@testable import HomeBasket

final class KitchenPlanCodeTests: XCTestCase {

    // MARK: - Known Code

    func testKnownExampleCode() {

        let code = KitchenPlanCode.encode(
            recipeID: "recipe002",
            servings: 2
        )

        XCTAssertEqual(code, "20291")
    }

    // MARK: - Decode Known Code

    func testDecodeKnownCode() {

        let meal = KitchenPlanCode.decode(
            "20291"
        )

        XCTAssertEqual(
            meal?.recipeID,
            "recipe002"
        )

        XCTAssertEqual(
            meal?.servings,
            2
        )
    }

    // MARK: - Round Trip

    func testAllRecipesAndServings() {

        for number in 1...6 {

            let recipeID = String(
                format: "recipe%03d",
                number
            )

            for servings in 1...12 {

                let code = KitchenPlanCode.encode(
                    recipeID: recipeID,
                    servings: servings
                )

                XCTAssertNotNil(code)

                let decoded = KitchenPlanCode.decode(
                    code ?? ""
                )

                XCTAssertEqual(
                    decoded?.recipeID,
                    recipeID
                )

                XCTAssertEqual(
                    decoded?.servings,
                    servings
                )
            }
        }
    }

    // MARK: - Unsupported Recipe

    func testUnsupportedRecipe() {

        let code = KitchenPlanCode.encode(
            recipeID: "recipe999",
            servings: 2
        )

        XCTAssertNil(code)
    }

    // MARK: - Invalid Servings

    func testInvalidServingCounts() {

        XCTAssertNil(
            KitchenPlanCode.encode(
                recipeID: "recipe001",
                servings: 0
            )
        )

        XCTAssertNil(
            KitchenPlanCode.encode(
                recipeID: "recipe001",
                servings: 13
            )
        )
    }

    // MARK: - Incorrect Checksum

    func testIncorrectChecksum() {

        XCTAssertNil(
            KitchenPlanCode.decode("20290")
        )
    }

    // MARK: - Invalid Input

    func testInvalidCodes() {

        let invalidCodes = [
            "",
            "2029",
            "202911",
            "00000",
            "70200",
            "20A91"
        ]

        for code in invalidCodes {

            XCTAssertNil(
                KitchenPlanCode.decode(code)
            )
        }
    }

    // MARK: - Different Serving Sizes

    func testDifferentServingsProduceDifferentCodes() {

        let twoServings = KitchenPlanCode.encode(
            recipeID: "recipe002",
            servings: 2
        )

        let fourServings = KitchenPlanCode.encode(
            recipeID: "recipe002",
            servings: 4
        )

        XCTAssertNotEqual(
            twoServings,
            fourServings
        )
    }
}
