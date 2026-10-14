
import Foundation
import SwiftData

enum MealType: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"

    var id: String { rawValue }

    var sortOrder: Int {
        switch self {
        case .breakfast: return 0
        case .lunch: return 1
        case .dinner: return 2
        }
    }
}

@Model
final class MealPlan {

    var id: UUID
    var recipeID: String
    var plannedDate: Date
    var mealType: String
    var servingCount: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        recipeID: String,
        plannedDate: Date,
        mealType: String,
        servingCount: Int
    ) {
        self.id = UUID()
        self.recipeID = recipeID
        self.plannedDate = Calendar.current.startOfDay(
            for: plannedDate
        )
        self.mealType = mealType
        self.servingCount = servingCount
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
