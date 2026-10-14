
import Foundation

struct MissingIngredient: Identifiable {
    let name: String
    let quantity: Double
    let unit: String

    var id: String {
        "\(name.lowercased())-\(unit.lowercased())"
    }
}

struct RecipeRecommendation: Identifiable {
    let recipe: Recipe
    let score: Double
    let availability: Double
    let expiryPriority: Double
    let missing: [MissingIngredient]
    let expiringIngredients: [String]

    var id: String { recipe.id }

    var scorePercent: Int {
        Int((score * 100).rounded())
    }

    var availabilityPercent: Int {
        Int((availability * 100).rounded())
    }
}

enum RecipeRecommendationEngine {

    static func recommend(
        recipes: [Recipe],
        pantryItems: [PantryItem],
        today: Date = Date(),
        favoriteRecipeIDs: Set<String> = []
    ) -> [RecipeRecommendation] {

        let usableItems = pantryItems.filter { item in
            guard item.quantity.isFinite,
                  item.quantity > 0 else {
                return false
            }

            if case .expired = ExpiryService.status(
                for: item.expiryDate,
                today: today
            ) {
                return false
            }

            return true
        }

        return recipes.compactMap { recipe -> RecipeRecommendation? in

            let requirements = recipe.ingredients.filter {
                $0.quantity.isFinite && $0.quantity > 0
            }

            guard !requirements.isEmpty else {
                return nil
            }

            var availabilityTotal = 0.0
            var expiryTotal = 0.0

            var missing: [MissingIngredient] = []
            var matchedNames = Set<String>()
            var expiringNames = Set<String>()

            for ingredient in requirements {

                var remaining = ingredient.quantity

                let matchingItems = usableItems
                    .filter {
                        normalizedName($0.name) ==
                        normalizedName(ingredient.name)
                    }
                    .sorted {
                        $0.expiryDate < $1.expiryDate
                    }

                for item in matchingItems {
                    guard remaining > 0.00001 else {
                        break
                    }

                    guard let available = convert(
                        item.quantity,
                        from: item.unit,
                        to: ingredient.unit
                    ) else {
                        continue
                    }

                    let used = min(remaining, available)

                    guard used > 0 else {
                        continue
                    }

                    remaining -= used
                    matchedNames.insert(ingredient.name)

                    if case .expiringSoon = ExpiryService.status(
                        for: item.expiryDate,
                        today: today
                    ) {

                        let calendar = Calendar.current

                        let days = calendar.dateComponents(
                            [.day],
                            from: calendar.startOfDay(for: today),
                            to: calendar.startOfDay(
                                for: item.expiryDate
                            )
                        ).day ?? 3

                        let urgency = max(
                            0,
                            min(1, (4.0 - Double(days)) / 4.0)
                        )

                        expiryTotal +=
                            (used / ingredient.quantity) * urgency

                        expiringNames.insert(ingredient.name)
                    }
                }

                let fulfilled = max(
                    0,
                    min(
                        1,
                        1 - remaining / ingredient.quantity
                    )
                )

                availabilityTotal += fulfilled

                if remaining > 0.00001 {
                    missing.append(
                        MissingIngredient(
                            name: ingredient.name,
                            quantity: remaining,
                            unit: ingredient.unit
                        )
                    )
                }
            }

            // Do not recommend unrelated recipes.
            guard !matchedNames.isEmpty else {
                return nil
            }

            let requirementCount = Double(requirements.count)

            let availability = availabilityTotal / requirementCount
            let expiryPriority = expiryTotal / requirementCount

            // Full quickness score at 30 minutes or less.
            // Decreases to zero at 90 minutes.
            let quickness = max(
                0,
                min(
                    1,
                    (90.0 - Double(recipe.totalMinutes)) / 60.0
                )
            )

            // Neutral until family preferences are implemented.
            let familyPreference = favoriteRecipeIDs.contains(
                recipe.id
            ) ? 1.0 : 0.5

            let score =
                0.45 * availability +
                0.35 * expiryPriority +
                0.10 * quickness +
                0.10 * familyPreference

            return RecipeRecommendation(
                recipe: recipe,
                score: score,
                availability: availability,
                expiryPriority: expiryPriority,
                missing: missing,
                expiringIngredients: expiringNames.sorted()
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.000001 {
                return $0.score > $1.score
            }

            return $0.recipe.name.localizedStandardCompare(
                $1.recipe.name
            ) == .orderedAscending
        }
    }

    private static func normalizedName(
        _ name: String
    ) -> String {

        let cleaned = name.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")

        let aliases: [String: String] = [
            "tomatoes": "tomato",
            "eggs": "egg",
            "carrots": "carrot",
            "chicken breast": "chicken"
        ]

        return aliases[cleaned] ?? cleaned
    }

    private static func measurement(
        for unit: String
    ) -> (dimension: String, factor: Double)? {

        switch unit.lowercased() {
        case "g":
            return ("mass", 1)
        case "kg":
            return ("mass", 1000)
        case "ml":
            return ("volume", 1)
        case "l":
            return ("volume", 1000)
        case "pcs":
            return ("count", 1)
        default:
            return nil
        }
    }

    private static func convert(
        _ quantity: Double,
        from sourceUnit: String,
        to targetUnit: String
    ) -> Double? {

        guard let source = measurement(for: sourceUnit),
              let target = measurement(for: targetUnit),
              source.dimension == target.dimension else {
            return nil
        }

        return quantity * source.factor / target.factor
    }
}
