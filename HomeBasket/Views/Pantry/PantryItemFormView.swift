
import SwiftUI
import SwiftData

struct PantryItemFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: PantryItem?

    @State private var name: String
    @State private var quantityText: String
    @State private var category: PantryCategory
    @State private var unit: PantryUnit
    @State private var storage: PantryStorage
    @State private var expiryDate: Date

    @State private var showError = false
    @State private var errorMessage = ""

    init(item: PantryItem? = nil) {
        self.item = item

        _name = State(initialValue: item?.name ?? "")
        _quantityText = State(
            initialValue: item.map { String($0.quantity) } ?? "1"
        )

        _category = State(
            initialValue: PantryCategory(
                rawValue: item?.category ?? ""
            ) ?? .vegetables
        )

        _unit = State(
            initialValue: PantryUnit(
                rawValue: item?.unit ?? ""
            ) ?? .pieces
        )

        _storage = State(
            initialValue: PantryStorage(
                rawValue: item?.storageLocation ?? ""
            ) ?? .refrigerator
        )

        _expiryDate = State(
            initialValue: item?.expiryDate
                ?? Calendar.current.date(
                    byAdding: .day,
                    value: 7,
                    to: Date()
                )
                ?? Date()
        )
    }

    private var validatedQuantity: Double? {
        let normalized = quantityText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard let value = Double(normalized),
              value.isFinite,
              value > 0 else {
            return nil
        }

        return value
    }

    private var trimmedName: String {
        name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
    }

    var body: some View {
        Form {

            Section("Ingredient Information") {
                TextField("Ingredient name", text: $name)
                    .textInputAutocapitalization(.words)

                Picker("Category", selection: $category) {
                    ForEach(PantryCategory.allCases) { category in
                        Text(category.rawValue)
                            .tag(category)
                    }
                }
            }

            Section("Quantity") {
                TextField("Quantity", text: $quantityText)
                    .keyboardType(.decimalPad)

                Picker("Unit", selection: $unit) {
                    ForEach(PantryUnit.allCases) { unit in
                        Text(unit.rawValue)
                            .tag(unit)
                    }
                }
            }

            Section("Storage and Expiry") {
                Picker("Storage Location", selection: $storage) {
                    ForEach(PantryStorage.allCases) { location in
                        Text(location.rawValue)
                            .tag(location)
                    }
                }

                DatePicker(
                    "Expiry Date",
                    selection: $expiryDate,
                    displayedComponents: .date
                )
            }

            Section {
                Text("Keep quantities accurate and update ingredients as they are used.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(
            item == nil ? "Add Ingredient" : "Edit Ingredient"
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
                    saveIngredient()
                }
                .disabled(
                    trimmedName.isEmpty
                    || validatedQuantity == nil
                )
            }
        }
        .alert(
            "Cannot Save Ingredient",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveIngredient() {
        guard !trimmedName.isEmpty,
              let quantity = validatedQuantity else {
            errorMessage = "Enter a valid name and quantity greater than zero."
            showError = true
            return
        }

        do {
            let existingItems = try modelContext.fetch(
                FetchDescriptor<PantryItem>()
            )

            let duplicate = existingItems.contains { existing in
                existing.id != item?.id
                && existing.name.localizedCaseInsensitiveCompare(
                    trimmedName
                ) == .orderedSame
                && existing.unit == unit.rawValue
                && existing.storageLocation == storage.rawValue
                && Calendar.current.isDate(
                    existing.expiryDate,
                    inSameDayAs: expiryDate
                )
            }

            if duplicate {
                errorMessage = "This ingredient batch already exists. Edit the existing item instead."
                showError = true
                return
            }

            if let item {
                item.name = trimmedName
                item.quantity = quantity
                item.category = category.rawValue
                item.unit = unit.rawValue
                item.storageLocation = storage.rawValue
                item.expiryDate = expiryDate
                item.updatedAt = Date()
            } else {
                let newItem = PantryItem(
                    name: trimmedName,
                    category: category.rawValue,
                    quantity: quantity,
                    unit: unit.rawValue,
                    expiryDate: expiryDate,
                    storageLocation: storage.rawValue
                )

                modelContext.insert(newItem)
            }

            try modelContext.save()
            dismiss()

        } catch {
            modelContext.rollback()
            errorMessage = "Database error: \(error.localizedDescription)"
            showError = true
        }
    }
}
