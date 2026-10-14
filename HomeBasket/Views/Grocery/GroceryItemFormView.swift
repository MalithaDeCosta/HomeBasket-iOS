
import SwiftUI
import SwiftData

struct GroceryItemFormView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: GroceryItem?

    @State private var name: String
    @State private var quantityText: String
    @State private var category: PantryCategory
    @State private var unit: PantryUnit

    @State private var showError = false
    @State private var errorMessage = ""

    init(item: GroceryItem? = nil) {
        self.item = item

        _name = State(initialValue: item?.name ?? "")

        _quantityText = State(
            initialValue: item.map {
                String($0.quantity)
            } ?? "1"
        )

        _category = State(
            initialValue: PantryCategory(
                rawValue: item?.category ?? ""
            ) ?? .other
        )

        _unit = State(
            initialValue: PantryUnit(
                rawValue: item?.unit ?? ""
            ) ?? .pieces
        )
    }

    private var cleanedName: String {
        name.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private var validQuantity: Double? {
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

    var body: some View {
        Form {

            Section("Grocery Information") {
                TextField("Item name", text: $name)
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

            Section {
                Text(
                    "Purchased items are tracked separately from items still needed."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(
            item == nil ? "Add Grocery" : "Edit Grocery"
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
                    saveGrocery()
                }
                .disabled(
                    cleanedName.isEmpty ||
                    validQuantity == nil
                )
            }
        }
        .alert(
            "Cannot Save Grocery",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveGrocery() {
        guard !cleanedName.isEmpty,
              let quantity = validQuantity else {
            errorMessage = "Enter a valid name and quantity greater than zero."
            showError = true
            return
        }

        do {
            let allItems = try modelContext.fetch(
                FetchDescriptor<GroceryItem>()
            )

            if item?.isPurchased != true {
                let duplicate = allItems.contains { existing in
                    existing.id != item?.id &&
                    !existing.isPurchased &&
                    existing.name.localizedCaseInsensitiveCompare(
                        cleanedName
                    ) == .orderedSame &&
                    existing.unit == unit.rawValue &&
                    existing.category == category.rawValue
                }

                if duplicate {
                    errorMessage = """
                    This item is already on your pending shopping list.
                    Edit its quantity instead of adding another entry.
                    """
                    showError = true
                    return
                }
            }

            if let item {
                item.name = cleanedName
                item.quantity = quantity
                item.category = category.rawValue
                item.unit = unit.rawValue
                item.updatedAt = Date()

            } else {
                let grocery = GroceryItem(
                    name: cleanedName,
                    quantity: quantity,
                    unit: unit.rawValue,
                    category: category.rawValue
                )

                modelContext.insert(grocery)
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
