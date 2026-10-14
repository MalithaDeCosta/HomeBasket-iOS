
import Foundation

struct DashboardSummary {
    let pantryCount: Int
    let freshCount: Int
    let expiringSoonCount: Int
    let expiredCount: Int
    let pendingGroceryCount: Int
    let purchasedGroceryCount: Int
}

enum DashboardSummaryService {

    static func calculate(
        pantryItems: [PantryItem],
        groceryItems: [GroceryItem],
        today: Date = Date()
    ) -> DashboardSummary {

        var freshCount = 0
        var expiringSoonCount = 0
        var expiredCount = 0

        for item in pantryItems {
            let status = ExpiryService.status(
                for: item.expiryDate,
                today: today
            )

            switch status {
            case .fresh:
                freshCount += 1

            case .expiringSoon:
                expiringSoonCount += 1

            case .expired:
                expiredCount += 1
            }
        }

        let pendingGroceryCount = groceryItems.filter {
            !$0.isPurchased
        }.count

        let purchasedGroceryCount = groceryItems.filter {
            $0.isPurchased
        }.count

        return DashboardSummary(
            pantryCount: pantryItems.count,
            freshCount: freshCount,
            expiringSoonCount: expiringSoonCount,
            expiredCount: expiredCount,
            pendingGroceryCount: pendingGroceryCount,
            purchasedGroceryCount: purchasedGroceryCount
        )
    }
}
