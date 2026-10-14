
import Foundation

// MARK: - Shared Meal Payload

struct KitchenSharedMeal: Equatable {

    let recipeID: String
    let servings: Int
}

// MARK: - HomeBasket Kitchen Transfer Code
//
// Format: RSSCC
//
// R  = recipe number (1...6)
// SS = servings (01...12)
// CC = validation checksum (00...96)
//
// Example:
// Recipe 2, 2 servings -> 20291
//
// The code does not transfer a date or meal type.
// It is designed for manual simulator-friendly handoff.

enum KitchenPlanCode {

    private static let recipeIDs = [
        "recipe001",
        "recipe002",
        "recipe003",
        "recipe004",
        "recipe005",
        "recipe006"
    ]

    // MARK: - Generate a Code

    static func encode(
        recipeID: String,
        servings: Int
    ) -> String? {

        guard let index = recipeIDs.firstIndex(
            of: recipeID
        ),
        (1...12).contains(servings) else {
            return nil
        }

        let recipeNumber = index + 1

        let checksum = checksum(
            recipeNumber: recipeNumber,
            servings: servings
        )

        return String(
            format: "%d%02d%02d",
            recipeNumber,
            servings,
            checksum
        )
    }

    // MARK: - Decode a Code

    static func decode(
        _ code: String
    ) -> KitchenSharedMeal? {

        guard code.count == 5,
              code.allSatisfy({
                  $0.wholeNumberValue != nil
              }),
              let recipeNumber = Int(
                  code.prefix(1)
              ),
              let servings = Int(
                  code.dropFirst().prefix(2)
              ),
              let suppliedChecksum = Int(
                  code.suffix(2)
              ),
              (1...recipeIDs.count).contains(
                  recipeNumber
              ),
              (1...12).contains(servings) else {
            return nil
        }

        let expectedChecksum = checksum(
            recipeNumber: recipeNumber,
            servings: servings
        )

        guard suppliedChecksum == expectedChecksum else {
            return nil
        }

        return KitchenSharedMeal(
            recipeID: recipeIDs[
                recipeNumber - 1
            ],
            servings: servings
        )
    }

    // MARK: - Validation Checksum

    private static func checksum(
        recipeNumber: Int,
        servings: Int
    ) -> Int {

        (
            recipeNumber * 29
            + servings * 13
            + 7
        ) % 97
    }
}
