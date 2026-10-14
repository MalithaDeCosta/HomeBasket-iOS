import Foundation
import SwiftData

struct GroceryImportSummary {
    let created: Int
    let updated: Int
    let alreadyCovered: Int

    var message: String {
        """
        New grocery entries: \(created)
        Existing entries updated: \(updated)
        Already covered: \(alreadyCovered)

        Open Grocery to review your shopping list.
        """
    }
}

enum GroceryImportError: LocalizedError {
    case invalidQuantity(String)
    case unsupportedUnit(String)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity(let name):
            return "Invalid missing quantity for \(name)."
        case .unsupportedUnit(let unit):
            return "Unsupported measurement unit: \(unit)."
        }
    }
}

@MainActor
enum GroceryImportService {

    static func addMissingIngredients(
        _ ingredients: [MissingIngredient],
        to context: ModelContext
    ) throws -> GroceryImportSummary {

        let allGroceries = try context.fetch(
            FetchDescriptor<GroceryItem>()
        )

        // Purchased groceries do not count toward the next shopping trip.
        var pending = allGroceries.filter { !$0.isPurchased }
        var created = 0
        var updated = 0
        var alreadyCovered = 0

        do {
            for ingredient in ingredients {
                guard ingredient.quantity.isFinite,
                      ingredient.quantity > 0 else {
                    throw GroceryImportError.invalidQuantity(ingredient.name)
                }

                guard measurement(for: ingredient.unit) != nil else {
                    throw GroceryImportError.unsupportedUnit(ingredient.unit)
                }

                let matches = pending
                    .filter { grocery in
                        normalizedName(grocery.name) == normalizedName(ingredient.name)
                        && measurement(for: grocery.unit)?.dimension ==
                           measurement(for: ingredient.unit)?.dimension
                    }
                    .sorted { $0.createdAt < $1.createdAt }

                // Sum equivalent quantities already on the pending list.
                let quantityAlreadyListed = matches.reduce(0.0) { total, grocery in
                    total + (convert(
                        grocery.quantity,
                        from: grocery.unit,
                        to: ingredient.unit
                    ) ?? 0)
                }

                let shortage = ingredient.quantity - quantityAlreadyListed

                // Tapping Import repeatedly must not multiply the quantity.
                if shortage <= 0.000001 {
                    alreadyCovered += 1
                    continue
                }

                if let existing = matches.first {
                    guard let additional = convert(
                        shortage,
                        from: ingredient.unit,
                        to: existing.unit
                    ) else {
                        throw GroceryImportError.unsupportedUnit(ingredient.unit)
                    }

                    existing.quantity += additional
                    existing.updatedAt = Date()
                    updated += 1
                } else {
                    let grocery = GroceryItem(
                        name: ingredient.name,
                        quantity: ingredient.quantity,
                        unit: ingredient.unit,
                        category: category(for: ingredient.name)
                    )
                    context.insert(grocery)
                    pending.append(grocery)
                    created += 1
                }
            }

            try context.save()
            return GroceryImportSummary(
                created: created,
                updated: updated,
                alreadyCovered: alreadyCovered
            )
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func normalizedName(_ name: String) -> String {
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

    private static func category(for name: String) -> String {
        switch normalizedName(name) {
        case "tomato", "carrot":
            return PantryCategory.vegetables.rawValue
        case "rice":
            return PantryCategory.grains.rawValue
        case "chicken":
            return PantryCategory.meat.rawValue
        case "milk":
            return PantryCategory.dairy.rawValue
        default:
            return PantryCategory.other.rawValue
        }
    }

    private static func measurement(
        for unit: String
    ) -> (dimension: String, factor: Double)? {
        switch unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "g": return ("mass", 1)
        case "kg": return ("mass", 1000)
        case "ml": return ("volume", 1)
        case "l": return ("volume", 1000)
        case "pcs": return ("count", 1)
        default: return nil
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
