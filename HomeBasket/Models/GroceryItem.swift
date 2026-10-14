
import Foundation
import SwiftData

@Model
final class GroceryItem {

    var id: UUID
    var name: String
    var quantity: Double
    var unit: String
    var category: String
    var isPurchased: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        quantity: Double,
        unit: String,
        category: String,
        isPurchased: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.isPurchased = isPurchased
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
