
import SwiftUI
import SwiftData

struct DashboardView: View {

    // MARK: - SwiftData Queries

    @Query(sort: \PantryItem.expiryDate)
    private var pantryItems: [PantryItem]

    @Query(sort: \GroceryItem.createdAt)
    private var groceryItems: [GroceryItem]

    @Query(sort: \MealPlan.plannedDate)
    private var mealPlans: [MealPlan]

    // MARK: - State

    @State private var mealRecipes: [Recipe] = []
    @State private var mealLoadError: String?

    // MARK: - Navigation Actions

    let openPantry: () -> Void
    let openGrocery: () -> Void
    let openRescue: () -> Void
    let openPlanner: () -> Void

    // MARK: - Grid Layout

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    // MARK: - Expiring Ingredients

    private var attentionItems: [PantryItem] {

        pantryItems.filter { item in

            switch ExpiryService.status(
                for: item.expiryDate
            ) {

            case .expired, .expiringSoon:
                return true

            case .fresh:
                return false
            }
        }
        .sorted {
            $0.expiryDate < $1.expiryDate
        }
    }

    // MARK: - Today's Meals

    private var todaysMealPlans: [MealPlan] {

        mealPlans
            .filter { plan in
                Calendar.current.isDate(
                    plan.plannedDate,
                    inSameDayAs: Date()
                )
            }
            .sorted { first, second in

                let firstOrder = MealType(
                    rawValue: first.mealType
                )?.sortOrder ?? 99

                let secondOrder = MealType(
                    rawValue: second.mealType
                )?.sortOrder ?? 99

                return firstOrder < secondOrder
            }
    }

    private func recipeName(
        for plan: MealPlan
    ) -> String {

        mealRecipes.first {
            $0.id == plan.recipeID
        }?.name ?? "Recipe Unavailable"
    }

    // MARK: - Main View

    var body: some View {

        let summary = DashboardSummaryService.calculate(
            pantryItems: pantryItems,
            groceryItems: groceryItems
        )

        ScrollView {

            VStack(alignment: .leading, spacing: 24) {

                // MARK: Welcome Header

                HStack(spacing: 12) {

                    VStack(alignment: .leading, spacing: 6) {

                        Text("Welcome to")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text("HomeBasket")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)

                        Text("Waste Less. Plan Smarter.")
                            .font(.subheadline)
                    }

                    Spacer()

                    Image(systemName: "basket.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.green)
                }

                // MARK: Household Overview

                VStack(alignment: .leading, spacing: 14) {

                    Text("Household Overview")
                        .font(.title2.bold())

                    LazyVGrid(
                        columns: columns,
                        spacing: 12
                    ) {

                        DashboardStatCard(
                            title: "Pantry Items",
                            value: summary.pantryCount,
                            symbol: "shippingbox.fill",
                            color: .green
                        )

                        DashboardStatCard(
                            title: "Expiring Soon",
                            value: summary.expiringSoonCount,
                            symbol: "clock.fill",
                            color: .orange
                        )

                        DashboardStatCard(
                            title: "Expired Items",
                            value: summary.expiredCount,
                            symbol: "exclamationmark.triangle.fill",
                            color: .red
                        )

                        DashboardStatCard(
                            title: "To Buy",
                            value: summary.pendingGroceryCount,
                            symbol: "cart.fill",
                            color: .blue
                        )
                    }
                }

                // MARK: Needs Attention

                VStack(alignment: .leading, spacing: 14) {

                    HStack {

                        Label(
                            "Needs Attention",
                            systemImage: "clock.fill"
                        )
                        .font(.headline)

                        Spacer()

                        Button(
                            "View All",
                            action: openPantry
                        )
                        .font(.subheadline)
                    }

                    if pantryItems.isEmpty {

                        Text(
                            "Your pantry is empty. Add ingredients to begin tracking expiry dates."
                        )
                        .foregroundStyle(.secondary)

                    } else if attentionItems.isEmpty {

                        Label(
                            "No ingredients need immediate attention.",
                            systemImage: "checkmark.circle.fill"
                        )
                        .foregroundStyle(.green)

                    } else {

                        ForEach(
                            Array(attentionItems.prefix(3)),
                            id: \.id
                        ) { item in

                            HStack(spacing: 10) {

                                Image(
                                    systemName: "shippingbox"
                                )
                                .foregroundStyle(.orange)

                                VStack(
                                    alignment: .leading,
                                    spacing: 4
                                ) {

                                    Text(item.name)
                                        .font(.subheadline.bold())

                                    Text(
                                        item.expiryDate.formatted(
                                            date: .abbreviated,
                                            time: .omitted
                                        )
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Text(
                                    ExpiryService.status(
                                        for: item.expiryDate
                                    ).title
                                )
                                .font(.caption2.bold())
                                .foregroundStyle(
                                    statusColor(
                                        for: item.expiryDate
                                    )
                                )
                            }
                            .padding(.vertical, 4)
                        }

                        if attentionItems.count > 3 {

                            Text(
                                "And \(attentionItems.count - 3) more ingredients..."
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .dashboardSection()

                // MARK: Today's Scheduled Meals

                VStack(alignment: .leading, spacing: 14) {

                    Label(
                        "Today's Meals",
                        systemImage: "fork.knife"
                    )
                    .font(.headline)

                    if todaysMealPlans.isEmpty {

                        Text("No meals planned for today.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                    } else if let mealLoadError {

                        Text(
                            "Could not load recipe details: \(mealLoadError)"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)

                    } else if mealRecipes.isEmpty {

                        ProgressView(
                            "Loading today's meals..."
                        )

                    } else {

                        ForEach(todaysMealPlans) { plan in

                            HStack(
                                alignment: .top,
                                spacing: 12
                            ) {

                                Image(
                                    systemName: "fork.knife.circle.fill"
                                )
                                .font(.title2)
                                .foregroundStyle(.green)

                                VStack(
                                    alignment: .leading,
                                    spacing: 5
                                ) {

                                    Text(plan.mealType)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(
                                        recipeName(for: plan)
                                    )
                                    .font(.subheadline.bold())

                                    Text(
                                        "\(plan.servingCount) servings"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Button(
                        action: openPlanner
                    ) {

                        Label(
                            "View Meal Planner",
                            systemImage: "arrow.right"
                        )
                        .font(.subheadline.bold())
                    }
                }
                .dashboardSection()

                // MARK: Quick Actions

                VStack(alignment: .leading, spacing: 14) {

                    Text("Quick Actions")
                        .font(.headline)

                    DashboardActionButton(
                        title: "Manage Pantry",
                        subtitle: "Add or update ingredients",
                        symbol: "shippingbox.fill",
                        action: openPantry
                    )

                    DashboardActionButton(
                        title: "Shopping List",
                        subtitle: "See groceries you still need",
                        symbol: "cart.fill",
                        action: openGrocery
                    )

                    DashboardActionButton(
                        title: "Smart Food Rescue",
                        subtitle: "Find recipes for your ingredients",
                        symbol: "leaf.fill",
                        action: openRescue
                    )

                    DashboardActionButton(
                        title: "Family Meal Planner",
                        subtitle: "View and schedule family meals",
                        symbol: "calendar",
                        action: openPlanner
                    )
                }
            }
            .padding()
        }
        .background(
            Color(.systemGroupedBackground)
        )
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .task {

            do {
                mealRecipes = try RecipeLibrary.load()
                mealLoadError = nil

            } catch {
                mealLoadError = error.localizedDescription
            }
        }
    }

    // MARK: - Expiry Status Color

    private func statusColor(
        for expiryDate: Date
    ) -> Color {

        switch ExpiryService.status(
            for: expiryDate
        ) {

        case .expired:
            return .red

        case .expiringSoon:
            return .orange

        case .fresh:
            return .green
        }
    }
}

// MARK: - Reusable Statistic Card

private struct DashboardStatCard: View {

    let title: String
    let value: Int
    let symbol: String
    let color: Color

    var body: some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)

            Text(value.formatted())
                .font(
                    .system(
                        size: 34,
                        weight: .bold,
                        design: .rounded
                    )
                )
                .contentTransition(.numericText())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(
            maxWidth: .infinity,
            minHeight: 112,
            alignment: .leading
        )
        .padding()
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18)
        )
        .accessibilityElement(
            children: .combine
        )
    }
}

// MARK: - Reusable Dashboard Action Button

private struct DashboardActionButton: View {

    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {

        Button(action: action) {

            HStack(spacing: 14) {

                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.green)
                    .frame(width: 28)

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable Dashboard Section Modifier

private struct DashboardSectionModifier: ViewModifier {

    func body(content: Content) -> some View {

        content
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(18)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18)
            )
    }
}

private extension View {

    func dashboardSection() -> some View {
        modifier(DashboardSectionModifier())
    }
}
