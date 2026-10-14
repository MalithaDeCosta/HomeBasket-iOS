
import Foundation

struct Recipe: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let preparationMinutes: Int
    let cookingMinutes: Int
    let servingCount: Int
    let symbol: String
    let ingredients: [RecipeIngredient]
    let steps: [String]

    var totalMinutes: Int {
        preparationMinutes + cookingMinutes
    }
}

struct RecipeIngredient: Codable, Identifiable {
    let name: String
    let quantity: Double
    let unit: String

    var id: String {
        "\(name.lowercased())-\(unit.lowercased())"
    }
}
