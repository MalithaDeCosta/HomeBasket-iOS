
import SwiftUI
import SwiftData
import UIKit

struct KitchenShareView: View {

    // MARK: - Saved Meal Plans

    @Query(sort: \MealPlan.plannedDate)
    private var mealPlans: [MealPlan]

    // MARK: - Recipe Library

    @State private var recipes: [Recipe] = []
    @State private var loadError: String?

    // MARK: - Copy State

    @State private var copiedPlanID: UUID?

    // MARK: - Main View

    var body: some View {

        List {

            // MARK: - Introduction

            Section {

                VStack(
                    alignment: .leading,
                    spacing: 12
                ) {

                    Label(
                        "Send a Meal to Apple TV",
                        systemImage: "tv"
                    )
                    .font(.headline)
                    .foregroundStyle(.green)

                    Text(
                        "Generate a five-digit code for a saved meal, then enter it in HomeBasket Kitchen on Apple TV."
                    )
                    .font(.subheadline)

                    Text(
                        "This is a manual transfer. The code includes the recipe and serving count, but not its date or meal type."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            // MARK: - Saved Meals

            Section("Saved Meal Plans") {

                if let loadError {

                    ContentUnavailableView(
                        "Recipe Library Error",
                        systemImage:
                            "exclamationmark.triangle",
                        description: Text(loadError)
                    )

                } else if mealPlans.isEmpty {

                    ContentUnavailableView(
                        "No Scheduled Meals",
                        systemImage: "calendar.badge.plus",
                        description: Text(
                            "Schedule a recipe in the Family Meal Planner first."
                        )
                    )

                } else if recipes.isEmpty {

                    ProgressView(
                        "Loading recipe library..."
                    )

                } else {

                    ForEach(mealPlans) { plan in

                        mealShareCard(for: plan)
                    }
                }
            }

            // MARK: - Instructions

            Section("How to Use on Apple TV") {

                Label(
                    "Open HomeBasket Kitchen.",
                    systemImage: "1.circle"
                )

                Label(
                    "Select Import iOS Meal.",
                    systemImage: "2.circle"
                )

                Label(
                    "Enter the five-digit code.",
                    systemImage: "3.circle"
                )

                Label(
                    "Open the imported recipe or begin cooking.",
                    systemImage: "4.circle"
                )
            }

            Section {

                Text(
                    "Changes to a meal plan do not update Apple TV automatically. Generate and import a new code whenever the recipe or serving count changes."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Share with Kitchen")
        .navigationBarTitleDisplayMode(.inline)
        .task {

            do {

                recipes = try RecipeLibrary.load()
                loadError = nil

            } catch {

                loadError = error.localizedDescription
            }
        }
    }

    // MARK: - Meal Share Card

    @ViewBuilder
    private func mealShareCard(
        for plan: MealPlan
    ) -> some View {

        let recipe = recipes.first {
            $0.id == plan.recipeID
        }

        VStack(
            alignment: .leading,
            spacing: 14
        ) {

            // MARK: Recipe Name

            HStack(spacing: 12) {

                Image(
                    systemName: recipe?.symbol
                        ?? "fork.knife"
                )
                .font(.title2)
                .foregroundStyle(.green)

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

                    Text(
                        recipe?.name
                            ?? "Recipe Unavailable"
                    )
                    .font(.headline)

                    Text(
                        "\(plan.mealType) • \(plan.plannedDate.formatted(date: .abbreviated, time: .omitted))"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            LabeledContent(
                "Servings",
                value: "\(plan.servingCount)"
            )

            // MARK: Transfer Code

            if let code = KitchenPlanCode.encode(
                recipeID: plan.recipeID,
                servings: plan.servingCount
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 10
                ) {

                    Text("Apple TV Meal Code")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(code)
                        .font(
                            .system(
                                size: 35,
                                weight: .bold,
                                design: .monospaced
                            )
                        )
                        .foregroundStyle(.green)
                        .textSelection(.enabled)

                    Button {

                        UIPasteboard.general.string = code

                        copiedPlanID = plan.id

                    } label: {

                        Label(
                            copiedPlanID == plan.id
                                ? "Copied to Clipboard"
                                : "Copy Meal Code",
                            systemImage:
                                copiedPlanID == plan.id
                                ? "checkmark"
                                : "doc.on.doc"
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(14)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.green.opacity(0.08),
                    in: RoundedRectangle(
                        cornerRadius: 14
                    )
                )

            } else {

                Label(
                    "This recipe or serving count cannot be transferred. Supported servings: 1–12.",
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, 8)
    }
}
