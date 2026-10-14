
import SwiftUI
import SwiftData

struct MealPlannerView: View {

    @Environment(\.modelContext)
    private var modelContext

    @Query(sort: \MealPlan.plannedDate)
    private var mealPlans: [MealPlan]

    @State private var recipes: [Recipe] = []
    @State private var loadError: String?

    @State private var selectedDate =
        Calendar.current.startOfDay(for: Date())

    @State private var showAddForm = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    // MARK: - Week Calculation

    private var weekDays: [Date] {
        let calendar = Calendar.current

        let start = calendar.dateInterval(
            of: .weekOfYear,
            for: selectedDate
        )?.start ?? calendar.startOfDay(
            for: selectedDate
        )

        return (0..<7).compactMap { offset in
            calendar.date(
                byAdding: .day,
                value: offset,
                to: start
            )
        }
    }

    private var selectedDayPlans: [MealPlan] {
        mealPlans
            .filter {
                Calendar.current.isDate(
                    $0.plannedDate,
                    inSameDayAs: selectedDate
                )
            }
            .sorted {
                let first = MealType(
                    rawValue: $0.mealType
                )?.sortOrder ?? 99

                let second = MealType(
                    rawValue: $1.mealType
                )?.sortOrder ?? 99

                return first < second
            }
    }

    private var plannedDaysThisWeek: Int {
        weekDays.filter { day in
            mealPlans.contains {
                Calendar.current.isDate(
                    $0.plannedDate,
                    inSameDayAs: day
                )
            }
        }.count
    }

    var body: some View {
        List {

            // MARK: - Weekly Navigation

            Section {
                HStack {

                    Button {
                        changeWeek(by: -7)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous week")

                    Spacer()

                    VStack(spacing: 4) {
                        Text("Weekly Meal Plan")
                            .font(.headline)

                        if let firstDay = weekDays.first {
                            Text(
                                firstDay.formatted(
                                    date: .abbreviated,
                                    time: .omitted
                                )
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        changeWeek(by: 7)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next week")
                }
                .buttonStyle(.borderless)

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(weekDays, id: \.self) { day in
                            dayButton(for: day)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)

                HStack {
                    Label(
                        "\(plannedDaysThisWeek) of 7 days planned",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Button("Today") {
                        selectedDate = Calendar.current
                            .startOfDay(for: Date())
                    }
                    .font(.subheadline)
                }
            }

            // MARK: - Meal List

            Section {
                if let loadError {
                    ContentUnavailableView(
                        "Recipe Library Error",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )

                } else if recipes.isEmpty {
                    ProgressView("Loading recipes...")

                } else if selectedDayPlans.isEmpty {
                    ContentUnavailableView(
                        "No Meals Planned",
                        systemImage: "calendar.badge.plus",
                        description: Text(
                            "Tap + to schedule a meal for this day."
                        )
                    )

                } else {
                    ForEach(selectedDayPlans) { plan in
                        NavigationLink {
                            PlannedMealDetailView(
                                plan: plan,
                                recipes: recipes
                            )
                        } label: {
                            mealRow(for: plan)
                        }
                    }
                    .onDelete { offsets in
                        deletePlans(
                            at: offsets,
                            from: selectedDayPlans
                        )
                    }
                }
            } header: {
                Text(
                    "Meals for " +
                    selectedDate.formatted(
                        date: .abbreviated,
                        time: .omitted
                    )
                )
            }

            // MARK: - Weekly Summary

            Section("Weekly Summary") {
                let count = mealPlans.filter { plan in
                    weekDays.contains { day in
                        Calendar.current.isDate(
                            plan.plannedDate,
                            inSameDayAs: day
                        )
                    }
                }.count

                LabeledContent(
                    "Scheduled Meals",
                    value: "\(count)"
                )

                LabeledContent(
                    "Days With Plans",
                    value: "\(plannedDaysThisWeek)"
                )
            }
        }
        .navigationTitle("Meal Planner")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(recipes.isEmpty)
                .accessibilityLabel("Schedule a meal")
            }
        }
        .sheet(isPresented: $showAddForm) {
            NavigationStack {
                MealPlanFormView(
                    initialDate: selectedDate,
                    recipes: recipes
                )
            }
        }
        .alert(
            "Unable to Delete Meal",
            isPresented: $showDeleteError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
        .task {
            do {
                recipes = try RecipeLibrary.load()
                loadError = nil

            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    // MARK: - Day Button

    private func dayButton(for day: Date) -> some View {

        let isSelected = Calendar.current.isDate(
            day,
            inSameDayAs: selectedDate
        )

        let hasPlan = mealPlans.contains {
            Calendar.current.isDate(
                $0.plannedDate,
                inSameDayAs: day
            )
        }

        return Button {
            selectedDate = day
        } label: {
            VStack(spacing: 8) {

                Text(
                    day.formatted(
                        .dateTime.weekday(.abbreviated)
                    )
                )
                .font(.caption)

                Text(
                    day.formatted(
                        .dateTime.day()
                    )
                )
                .font(.headline)

                Circle()
                    .fill(
                        hasPlan
                        ? (isSelected ? Color.white : .green)
                        : .clear
                    )
                    .frame(width: 5, height: 5)
            }
            .frame(minWidth: 45)
            .padding(8)
            .foregroundStyle(
                isSelected ? Color.white : Color.primary
            )
            .background(
                isSelected
                ? Color.green
                : Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 12)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            day.formatted(
                date: .complete,
                time: .omitted
            )
        )
    }

    // MARK: - Meal Row

    private func mealRow(
        for plan: MealPlan
    ) -> some View {

        let recipe = recipes.first {
            $0.id == plan.recipeID
        }

        return HStack(spacing: 14) {

            Image(systemName: "fork.knife")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 35)

            VStack(alignment: .leading, spacing: 5) {

                Text(recipe?.name ?? "Recipe Unavailable")
                    .font(.headline)

                Text(plan.mealType)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("\(plan.servingCount) servings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let recipe {
                Text("\(recipe.totalMinutes) min")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: - Week Navigation

    private func changeWeek(by days: Int) {
        if let date = Calendar.current.date(
            byAdding: .day,
            value: days,
            to: selectedDate
        ) {
            selectedDate = date
        }
    }

    // MARK: - Delete Meal

    private func deletePlans(
        at offsets: IndexSet,
        from visiblePlans: [MealPlan]
    ) {
        for index in offsets {
            guard visiblePlans.indices.contains(index) else {
                continue
            }

            modelContext.delete(visiblePlans[index])
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            deleteErrorMessage = error.localizedDescription
            showDeleteError = true
        }
    }
}

// MARK: - Planned Meal Details

private struct PlannedMealDetailView: View {

    let plan: MealPlan
    let recipes: [Recipe]

    @State private var showEditForm = false

    private var recipe: Recipe? {
        recipes.first {
            $0.id == plan.recipeID
        }
    }

    var body: some View {
        List {

            if let recipe {

                Section("Scheduled Meal") {

                    LabeledContent(
                        "Meal",
                        value: plan.mealType
                    )

                    LabeledContent(
                        "Date",
                        value: plan.plannedDate.formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                    )

                    LabeledContent(
                        "Servings",
                        value: "\(plan.servingCount)"
                    )

                    LabeledContent(
                        "Total Time",
                        value: "\(recipe.totalMinutes) min"
                    )
                }

                Section("Recipe") {
                    Text(recipe.description)
                }

                Section("Required Ingredients") {

                    ForEach(recipe.ingredients) { ingredient in

                        let adjustedQuantity =
                            ingredient.quantity *
                            Double(plan.servingCount) /
                            Double(max(1, recipe.servingCount))

                        HStack {
                            Text(ingredient.name)

                            Spacer()

                            Text(
                                "\(adjustedQuantity.formatted()) \(ingredient.unit)"
                            )
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Cooking Instructions") {

                    ForEach(
                        recipe.steps.indices,
                        id: \.self
                    ) { index in

                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1).")
                                .fontWeight(.bold)
                                .foregroundStyle(.green)

                            Text(recipe.steps[index])
                        }
                        .padding(.vertical, 4)
                    }
                }

            } else {

                Section {
                    ContentUnavailableView(
                        "Recipe Not Available",
                        systemImage: "fork.knife",
                        description: Text(
                            "The recipe linked to this meal was not found."
                        )
                    )
                }
            }
        }
        .navigationTitle(
            recipe?.name ?? "Planned Meal"
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditForm = true
                }
            }
        }
        .sheet(isPresented: $showEditForm) {
            NavigationStack {
                MealPlanFormView(
                    plan: plan,
                    initialDate: plan.plannedDate,
                    recipes: recipes
                )
            }
        }
    }
}
