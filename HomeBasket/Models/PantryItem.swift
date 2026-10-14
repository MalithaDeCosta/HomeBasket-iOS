
import Foundation
import SwiftData

@Model
final class PantryItem {
    var id: UUID
    var name: String
    var category: String
    var quantity: Double
    var unit: String
    var expiryDate: Date
    var storageLocation: String
    var createdAt: Date
    var updatedAt: Date

    init(
        name: String,
        category: String,
        quantity: Double,
        unit: String,
        expiryDate: Date,
        storageLocation: String
    ) {
        self.id = UUID()
        self.name = name
        self.category = category
        self.quantity = quantity
        self.unit = unit
        self.expiryDate = expiryDate
        self.storageLocation = storageLocation
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum PantryCategory: String, CaseIterable, Identifiable {
    case vegetables = "Vegetables"
    case fruits = "Fruits"
    case grains = "Grains"
    case dairy = "Dairy"
    case meat = "Meat"
    case other = "Other"

    var id: String { rawValue }
}

enum PantryUnit: String, CaseIterable, Identifiable {
    case pieces = "pcs"
    case grams = "g"
    case kilograms = "kg"
    case milliliters = "ml"
    case liters = "L"

    var id: String { rawValue }
}

enum PantryStorage: String, CaseIterable, Identifiable {
    case refrigerator = "Refrigerator"
    case freezer = "Freezer"
    case cupboard = "Cupboard"

    var id: String { rawValue }
}
