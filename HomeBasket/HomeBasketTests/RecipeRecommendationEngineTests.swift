
import Foundation
import XCTest
@testable import HomeBasket

@MainActor
final class RecipeRecommendationEngineTests: XCTestCase {

    // MARK: - Test Helpers

    // Fixed date makes test results repeatable.
    private var testDate: Date {
        Calendar.current.date(
            from: DateComponents(
                year: 2026,
                month: 11,
                day: 15,
                hour: 12
            )
        )!
    }

    private func date(after days: Int) -> Date {
        Calendar.current.date(
            byAdding: .day,
            value: days,
            to: testDate
        )!
    }

    private func makePantryItem(
        name: String,
        quantity: Double,
        unit: String,
        expiresIn days: Int = 10
    ) -> PantryItem {
        PantryItem(
            name: name,
            category: "Other",
            quantity: quantity,
            unit: unit,
            expiryDate: date(after: days),
            storageLocation: "Refrigerator"
        )
    }

    private func ingredient(
        _ name: String,
        _ quantity: Double,
        _ unit: String
    ) -> RecipeIngredient {
        RecipeIngredient(
            name: name,
            quantity: quantity,
            unit: unit
        )
    }

    private func makeRecipe(
        _ ingredients: [RecipeIngredient],
        id: String = "test-recipe",
        name: String = "Test Recipe",
        preparation: Int = 10,
        cooking: Int = 20
    ) -> Recipe {
        Recipe(
            id: id,
            name: name,
            description: "Unit test recipe",
            preparationMinutes: preparation,
            cookingMinutes: cooking,
            servingCount: 2,
            symbol: "fork.knife",
            ingredients: ingredients,
            steps: ["Prepare ingredients", "Cook"]
        )
    }

    private func recommend(
        _ recipe: Recipe,
        pantry: [PantryItem],
        favorites: Set<String> = []
    ) -> RecipeRecommendation? {
        RecipeRecommendationEngine.recommend(
            recipes: [recipe],
            pantryItems: pantry,
            today: testDate,
            favoriteRecipeIDs: favorites
        ).first
    }

    // MARK: - Ingredient Matching Tests

    func testFullIngredientAvailability() {
        let recipe = makeRecipe([
            ingredient("Chicken", 200, "g"),
            ingredient("Rice", 150, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Chicken", quantity: 500, unit: "g"
            ),
            makePantryItem(
                name: "Rice", quantity: 1000, unit: "g"
            )
        ]

        guard let result = recommend(recipe, pantry: pantry) else {
            XCTFail("Expected a recommendation")
            return
        }

        XCTAssertEqual(
            result.availability,
            1.0,
            accuracy: 0.0001
        )
        XCTAssertTrue(result.missing.isEmpty)
    }

    func testPartialQuantityCalculation() {
        let recipe = makeRecipe([
            ingredient("Chicken", 200, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Chicken", quantity: 100, unit: "g"
            )
        ]

        guard let result = recommend(recipe, pantry: pantry) else {
            XCTFail("Expected partial recommendation")
            return
        }

        XCTAssertEqual(
            result.availability,
            0.5,
            accuracy: 0.0001
        )

        XCTAssertEqual(result.missing.count, 1)

        XCTAssertEqual(
            result.missing[0].quantity,
            100,
            accuracy: 0.0001
        )
    }

    func testKilogramToGramConversion() {
        let recipe = makeRecipe([
            ingredient("Rice", 150, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 1, unit: "kg"
            )
        ]

        let result = recommend(recipe, pantry: pantry)

        XCTAssertEqual(result?.availability, 1.0)
        XCTAssertTrue(result?.missing.isEmpty == true)
    }

    func testLiterToMilliliterConversion() {
        let recipe = makeRecipe([
            ingredient("Milk", 250, "ml")
        ])

        let pantry = [
            makePantryItem(
                name: "Milk", quantity: 1, unit: "L"
            )
        ]

        let result = recommend(recipe, pantry: pantry)

        XCTAssertEqual(result?.availability, 1.0)
        XCTAssertTrue(result?.missing.isEmpty == true)
    }

    func testMultiplePantryBatchesCombine() {
        let recipe = makeRecipe([
            ingredient("Rice", 100, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 40, unit: "g"
            ),
            makePantryItem(
                name: "Rice", quantity: 60, unit: "g"
            )
        ]

        let result = recommend(recipe, pantry: pantry)

        XCTAssertEqual(result?.availability, 1.0)
        XCTAssertTrue(result?.missing.isEmpty == true)
    }

    func testIncompatibleUnitsAreNotConverted() {
        let recipe = makeRecipe([
            ingredient("Rice", 100, "g"),
            ingredient("Milk", 250, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 200, unit: "g"
            ),
            makePantryItem(
                name: "Milk", quantity: 1, unit: "L"
            )
        ]

        guard let result = recommend(recipe, pantry: pantry) else {
            XCTFail("Expected a partially matching recipe")
            return
        }

        XCTAssertEqual(
            result.availability,
            0.5,
            accuracy: 0.0001
        )

        XCTAssertEqual(result.missing.count, 1)
        XCTAssertEqual(result.missing[0].name, "Milk")
        XCTAssertEqual(result.missing[0].unit, "g")
    }

    // MARK: - Expiry Tests

    func testExpiredOnlyIngredientIsExcluded() {
        let recipe = makeRecipe([
            ingredient("Chicken", 200, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Chicken",
                quantity: 500,
                unit: "g",
                expiresIn: -1
            )
        ]

        XCTAssertNil(recommend(recipe, pantry: pantry))
    }

    func testExpiredIngredientIsReportedMissing() {
        let recipe = makeRecipe([
            ingredient("Rice", 100, "g"),
            ingredient("Chicken", 200, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 200, unit: "g"
            ),
            makePantryItem(
                name: "Chicken",
                quantity: 500,
                unit: "g",
                expiresIn: -1
            )
        ]

        guard let result = recommend(recipe, pantry: pantry) else {
            XCTFail("Expected recipe matching Rice")
            return
        }

        XCTAssertEqual(result.missing.count, 1)
        XCTAssertEqual(result.missing[0].name, "Chicken")

        XCTAssertEqual(
            result.missing[0].quantity,
            200,
            accuracy: 0.0001
        )
    }

    func testIngredientExpiringTodayIsUsable() {
        let recipe = makeRecipe([
            ingredient("Tomatoes", 2, "pcs")
        ])

        let pantry = [
            makePantryItem(
                name: "Tomatoes",
                quantity: 3,
                unit: "pcs",
                expiresIn: 0
            )
        ]

        let result = recommend(recipe, pantry: pantry)

        XCTAssertEqual(result?.availability, 1.0)
        XCTAssertTrue(result?.missing.isEmpty == true)
    }

    func testExpiringSoonBoostsRecommendationScore() {
        let recipe = makeRecipe([
            ingredient("Chicken", 200, "g")
        ])

        let soon = makePantryItem(
            name: "Chicken",
            quantity: 300,
            unit: "g",
            expiresIn: 1
        )

        let later = makePantryItem(
            name: "Chicken",
            quantity: 300,
            unit: "g",
            expiresIn: 15
        )

        guard let soonResult = recommend(
            recipe, pantry: [soon]
        ), let laterResult = recommend(
            recipe, pantry: [later]
        ) else {
            XCTFail("Expected both recommendations")
            return
        }

        XCTAssertGreaterThan(
            soonResult.score,
            laterResult.score
        )
    }

    // MARK: - Recipe Ranking Tests

    func testIngredientAliases() {
        let recipe = makeRecipe([
            ingredient("Tomato", 2, "pcs")
        ])

        let pantry = [
            makePantryItem(
                name: "Tomatoes",
                quantity: 3,
                unit: "pcs"
            )
        ]

        let result = recommend(recipe, pantry: pantry)

        XCTAssertEqual(result?.availability, 1.0)
    }

    func testUnrelatedRecipesAreExcluded() {
        let riceRecipe = makeRecipe(
            [ingredient("Rice", 100, "g")],
            id: "rice",
            name: "Rice Recipe"
        )

        let eggRecipe = makeRecipe(
            [ingredient("Eggs", 2, "pcs")],
            id: "eggs",
            name: "Egg Recipe"
        )

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 500, unit: "g"
            )
        ]

        let results = RecipeRecommendationEngine.recommend(
            recipes: [riceRecipe, eggRecipe],
            pantryItems: pantry,
            today: testDate
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.recipe.id, "rice")
    }

    func testBetterIngredientMatchRanksHigher() {
        let complete = makeRecipe(
            [ingredient("Rice", 100, "g")],
            id: "complete",
            name: "Complete Recipe"
        )

        let partial = makeRecipe(
            [
                ingredient("Rice", 100, "g"),
                ingredient("Eggs", 2, "pcs")
            ],
            id: "partial",
            name: "Partial Recipe"
        )

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 500, unit: "g"
            )
        ]

        let results = RecipeRecommendationEngine.recommend(
            recipes: [partial, complete],
            pantryItems: pantry,
            today: testDate
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first?.recipe.id, "complete")
    }

    func testShorterRecipeScoresHigher() {
        let quick = makeRecipe(
            [ingredient("Rice", 100, "g")],
            preparation: 10,
            cooking: 20
        )

        let slow = makeRecipe(
            [ingredient("Rice", 100, "g")],
            preparation: 30,
            cooking: 60
        )

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 500, unit: "g"
            )
        ]

        guard let quickResult = recommend(
            quick, pantry: pantry
        ), let slowResult = recommend(
            slow, pantry: pantry
        ) else {
            XCTFail("Expected both recommendations")
            return
        }

        XCTAssertGreaterThan(
            quickResult.score,
            slowResult.score
        )
    }

    func testFavoriteRecipeGetsHigherScore() {
        let recipe = makeRecipe([
            ingredient("Rice", 100, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 200, unit: "g"
            )
        ]

        guard let normal = recommend(
            recipe, pantry: pantry
        ), let favorite = recommend(
            recipe,
            pantry: pantry,
            favorites: ["test-recipe"]
        ) else {
            XCTFail("Expected recommendations")
            return
        }

        XCTAssertEqual(
            favorite.score - normal.score,
            0.05,
            accuracy: 0.0001
        )
    }

    // MARK: - Edge Cases

    func testEmptyPantryReturnsNoRecommendations() {
        let recipe = makeRecipe([
            ingredient("Rice", 100, "g")
        ])

        XCTAssertNil(recommend(recipe, pantry: []))
    }

    func testInvalidPantryQuantityIsIgnored() {
        let recipe = makeRecipe([
            ingredient("Rice", 100, "g")
        ])

        let pantry = [
            makePantryItem(
                name: "Rice", quantity: 0, unit: "g"
            )
        ]

        XCTAssertNil(recommend(recipe, pantry: pantry))
    }

    func testExactWeightedScore() {
        let recipe = makeRecipe(
            [ingredient("Chicken", 200, "g")],
            preparation: 10,
            cooking: 20
        )

        let pantry = [
            makePantryItem(
                name: "Chicken",
                quantity: 200,
                unit: "g",
                expiresIn: 1
            )
        ]

        guard let result = recommend(recipe, pantry: pantry) else {
            XCTFail("Expected recommendation")
            return
        }

        // Availability = 1.0
        // Expiry urgency = 0.75
        // Quickness = 1.0
        // Neutral preference = 0.5

        let expected =
            0.45 * 1.0 +
            0.35 * 0.75 +
            0.10 * 1.0 +
            0.10 * 0.5

        XCTAssertEqual(
            result.score,
            expected,
            accuracy: 0.0001
        )

        XCTAssertEqual(result.scorePercent, 86)
    }
}
