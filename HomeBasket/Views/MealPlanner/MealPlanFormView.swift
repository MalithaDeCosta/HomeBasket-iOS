
import SwiftUI
import SwiftData

struct MealPlanFormView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Environment(\.dismiss)
    private var dismiss

    @Query
    private var existingPlans: [MealPlan]

    let plan: MealPlan?
    let recipes: [Recipe]

    @State private var recipeID: String
    @State private var plannedDate: Date
    @State private var mealType: MealType
    @State private var servingCount: Int

    @State private var showError = false
    @State private var errorMessage = ""

    init(
        plan: MealPlan? = nil,
        initialDate: Date,
        recipes: [Recipe]
    ) {
        self.plan = plan
        self.recipes = recipes

        _recipeID = State(
            initialValue: plan?.recipeID
                ?? recipes.first?.id
                ?? ""
        )

        _plannedDate = State(
            initialValue: plan?.plannedDate ?? initialDate
        )

        _mealType = State(
            initialValue: MealType(
                rawValue: plan?.mealType ?? ""
            ) ?? .dinner
        )

        _servingCount = State(
            initialValue: plan?.servingCount
                ?? recipes.first?.servingCount
                ?? 2
        )
    }

    private var selectedRecipe: Recipe? {
        recipes.first { $0.id == recipeID }
    }

    var body: some View {
        Form {

            Section("Choose Recipe") {
                Picker("Recipe", selection: $recipeID) {
                    ForEach(recipes) { recipe in
                        Text(recipe.name)
                            .tag(recipe.id)
                    }
                }

                if let selectedRecipe {
                    Text(selectedRecipe.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LabeledContent(
                        "Cooking Time",
                        value: "\(selectedRecipe.totalMinutes) min"
                    )
                }
            }

            Section("Meal Schedule") {
                DatePicker(
                    "Planned Date",
                    selection: $plannedDate,
                    displayedComponents: .date
                )

                Picker("Meal Type", selection: $mealType) {
                    ForEach(MealType.allCases) { type in
                        Text(type.rawValue)
                            .tag(type)
                    }
                }
            }

            Section("Serving Size") {
                Stepper(
                    "Servings: \(servingCount)",
                    value: $servingCount,
                    in: 1...12
                )
            }

            Section {
                Text(
                    "Each day can have one breakfast, one lunch and one dinner plan. Choose another slot to avoid duplicates."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(
            plan == nil ? "Schedule Meal" : "Edit Meal"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {

            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savePlan()
                }
                .disabled(selectedRecipe == nil)
            }
        }
        .alert(
            "Cannot Save Meal",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func savePlan() {

        guard selectedRecipe != nil else {
            errorMessage = "Select a valid recipe."
            showError = true
            return
        }

        let date = Calendar.current.startOfDay(
            for: plannedDate
        )

        let duplicate = existingPlans.contains { existing in
            existing.id != plan?.id &&
            Calendar.current.isDate(
                existing.plannedDate,
                inSameDayAs: date
            ) &&
            existing.mealType == mealType.rawValue
        }

        if duplicate {
            errorMessage = """
            A \(mealType.rawValue.lowercased()) meal
            is already planned for this date.
            Edit that meal or choose another slot.
            """
            showError = true
            return
        }

        do {
            if let plan {
                plan.recipeID = recipeID
                plan.plannedDate = date
                plan.mealType = mealType.rawValue
                plan.servingCount = servingCount
                plan.updatedAt = Date()

            } else {
                let newPlan = MealPlan(
                    recipeID: recipeID,
                    plannedDate: date,
                    mealType: mealType.rawValue,
                    servingCount: servingCount
                )

                modelContext.insert(newPlan)
            }

            try modelContext.save()
            dismiss()

        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
