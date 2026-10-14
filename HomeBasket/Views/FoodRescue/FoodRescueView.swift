
import SwiftUI
import SwiftData

struct FoodRescueView: View {

    // MARK: - Navigation Callbacks

    let openGrocery: () -> Void
    let openPlanner: () -> Void

    // MARK: - Pantry Data

    @Query(sort: \PantryItem.expiryDate)
    private var pantryItems: [PantryItem]

    // MARK: - State

    @State private var recipes: [Recipe] = []
    @State private var loadError: String?

    // MARK: - Recommendations

    private var recommendations: [RecipeRecommendation] {

        RecipeRecommendationEngine.recommend(
            recipes: recipes,
            pantryItems: pantryItems
        )
    }

    // MARK: - Main View

    var body: some View {

        List {

            Section {

                VStack(
                    alignment: .leading,
                    spacing: 8
                ) {

                    Label(
                        "Waste Less, Cook Smarter",
                        systemImage: "leaf.fill"
                    )
                    .font(.headline)
                    .foregroundStyle(.green)

                    Text(
                        "Discover meals using your available pantry ingredients, prioritizing food that is close to expiring."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    Text(
                        "\(pantryItems.count) pantry records"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // MARK: - Error and Empty States

            if let loadError {

                Section {

                    ContentUnavailableView(
                        "Recipe Library Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                }

            } else if pantryItems.isEmpty {

                Section {

                    ContentUnavailableView(
                        "Your Pantry Is Empty",
                        systemImage: "shippingbox",
                        description: Text(
                            "Add ingredients in the Pantry tab to discover suitable recipes."
                        )
                    )
                }

            } else if recipes.isEmpty {

                Section {

                    ProgressView("Loading recipes...")
                }

            } else if recommendations.isEmpty {

                Section {

                    ContentUnavailableView(
                        "No Matching Recipes",
                        systemImage: "fork.knife",
                        description: Text(
                            "No available pantry ingredients match the current recipe library."
                        )
                    )
                }

            } else {

                // MARK: - Recommended Recipes

                Section {

                    ForEach(recommendations) { result in

                        NavigationLink {

                            RecipeRecommendationDetailView(
                                recommendation: result,
                                openGrocery: openGrocery,
                                openPlanner: openPlanner
                            )

                        } label: {

                            recommendationRow(result)
                        }
                    }

                } header: {

                    Text(
                        "Recommended Meals (\(recommendations.count))"
                    )

                } footer: {

                    Text(
                        "Rankings reflect ingredient availability, expiry priority, cooking time and family preference."
                    )
                }
            }
        }
        .navigationTitle("Smart Food Rescue")
        .task {

            do {
                recipes = try RecipeLibrary.load()
                loadError = nil

            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    // MARK: - Recommendation Row

    private func recommendationRow(
        _ result: RecipeRecommendation
    ) -> some View {

        VStack(
            alignment: .leading,
            spacing: 12
        ) {

            HStack(
                alignment: .top,
                spacing: 12
            ) {

                Image(
                    systemName: result.recipe.symbol
                )
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 35)

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {

                    Text(result.recipe.name)
                        .font(.headline)

                    Text(result.recipe.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                VStack(
                    alignment: .trailing,
                    spacing: 3
                ) {

                    Text(
                        "\(result.scorePercent)"
                    )
                    .font(.title2.bold())
                    .foregroundStyle(.green)

                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {

                Label(
                    "\(result.recipe.totalMinutes) min",
                    systemImage: "clock"
                )

                Text(
                    "\(result.availabilityPercent)% available"
                )
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !result.expiringIngredients.isEmpty {

                Label(
                    "Uses expiring: " +
                    result.expiringIngredients.joined(
                        separator: ", "
                    ),
                    systemImage: "leaf.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            if result.missing.isEmpty {

                Label(
                    "All tracked ingredients available",
                    systemImage: "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(.green)

            } else {

                Text(
                    "\(result.missing.count) ingredients still needed"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Recipe Detail Screen

private struct RecipeRecommendationDetailView: View {

    // MARK: - SwiftData Context

    @Environment(\.modelContext)
    private var modelContext

    // MARK: - Properties

    let recommendation: RecipeRecommendation
    let openGrocery: () -> Void
    let openPlanner: () -> Void

    // MARK: - State

    @State private var showScheduleForm = false
    @State private var showImportSuccess = false
    @State private var showImportError = false

    @State private var importMessage = ""
    @State private var errorMessage = ""

    private var recipe: Recipe {
        recommendation.recipe
    }

    // MARK: - Main Detail View

    var body: some View {

        List {

            // MARK: Recipe Overview

            Section("Recipe Overview") {

                Text(recipe.description)

                LabeledContent(
                    "Preparation",
                    value: "\(recipe.preparationMinutes) min"
                )

                LabeledContent(
                    "Cooking",
                    value: "\(recipe.cookingMinutes) min"
                )

                LabeledContent(
                    "Servings",
                    value: "\(recipe.servingCount)"
                )
            }

            // MARK: Why This Recipe

            Section("Why This Recipe?") {

                LabeledContent(
                    "Overall Score",
                    value: "\(recommendation.scorePercent)/100"
                )

                LabeledContent(
                    "Ingredient Availability",
                    value: "\(recommendation.availabilityPercent)%"
                )

                if !recommendation.expiringIngredients.isEmpty {

                    Text(
                        "Helps use: " +
                        recommendation.expiringIngredients.joined(
                            separator: ", "
                        )
                    )
                    .foregroundStyle(.orange)
                }

                Text(
                    "The score considers ingredient availability, expiry urgency, preparation time and family preference."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // MARK: Required Ingredients

            Section("Required Ingredients") {

                ForEach(recipe.ingredients) { ingredient in

                    HStack {

                        Text(ingredient.name)

                        Spacer()

                        Text(
                            "\(ingredient.quantity.formatted()) \(ingredient.unit)"
                        )
                        .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: Missing Ingredients

            Section("Missing Ingredients") {

                if recommendation.missing.isEmpty {

                    Label(
                        "All tracked ingredients available",
                        systemImage: "checkmark.circle.fill"
                    )
                    .foregroundStyle(.green)

                } else {

                    ForEach(recommendation.missing) { ingredient in

                        HStack {

                            Text(ingredient.name)

                            Spacer()

                            Text(
                                "\(ingredient.quantity.formatted()) \(ingredient.unit)"
                            )
                            .foregroundStyle(.orange)
                        }
                    }

                    // Add Missing Ingredients to Grocery

                    Button {

                        importMissingIngredients()

                    } label: {

                        Label(
                            "Add Missing Ingredients to Grocery",
                            systemImage: "cart.badge.plus"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .padding(.vertical, 8)
                }
            }

            // MARK: Family Meal Planner Integration

            Section("Family Meal Planner") {

                Button {

                    showScheduleForm = true

                } label: {

                    Label(
                        "Schedule This Recipe",
                        systemImage: "calendar.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .padding(.vertical, 6)

                Button {

                    openPlanner()

                } label: {

                    Label(
                        "View Meal Planner",
                        systemImage: "calendar"
                    )
                }

                Text(
                    "Choose a date, meal type and number of servings."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            // MARK: Cooking Instructions

            Section("Cooking Instructions") {

                ForEach(
                    recipe.steps.indices,
                    id: \.self
                ) { index in

                    HStack(
                        alignment: .top,
                        spacing: 12
                    ) {

                        Text("\(index + 1).")
                            .fontWeight(.bold)
                            .foregroundStyle(.green)

                        Text(recipe.steps[index])
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)

        // MARK: - Schedule Recipe Sheet

        .sheet(
            isPresented: $showScheduleForm
        ) {

            NavigationStack {

                MealPlanFormView(
                    initialDate: Date(),
                    recipes: [recipe]
                )
            }
        }

        // MARK: - Grocery Import Success

        .alert(
            "Grocery List Updated",
            isPresented: $showImportSuccess
        ) {

            Button("Open Grocery") {
                openGrocery()
            }

            Button(
                "Stay Here",
                role: .cancel
            ) {}

        } message: {

            Text(importMessage)
        }

        // MARK: - Grocery Import Error

        .alert(
            "Unable to Update Grocery",
            isPresented: $showImportError
        ) {

            Button(
                "OK",
                role: .cancel
            ) {}

        } message: {

            Text(errorMessage)
        }
    }

    // MARK: - Import Missing Ingredients

    private func importMissingIngredients() {

        do {

            let summary = try GroceryImportService
                .addMissingIngredients(
                    recommendation.missing,
                    to: modelContext
                )

            importMessage = summary.message
            showImportSuccess = true

        } catch {

            errorMessage = error.localizedDescription
            showImportError = true
        }
    }
}
