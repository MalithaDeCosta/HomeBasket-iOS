
import SwiftUI
import SwiftData

struct GroceryTransferView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: GroceryItem

    @State private var expiryDate = Date()
    @State private var storage: PantryStorage = .refrigerator

    @State private var showConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        Form {

            Section("Purchased Ingredient") {
                LabeledContent("Name", value: item.name)

                LabeledContent(
                    "Quantity",
                    value: "\(item.quantity.formatted()) \(item.unit)"
                )

                LabeledContent("Category", value: item.category)
            }

            Section("Pantry Details") {
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
                Text(
                    "Confirm the actual expiry date before moving this ingredient. Today's date is selected by default."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Move to Pantry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Move") {
                    showConfirmation = true
                }
            }
        }
        .confirmationDialog(
            "Move this ingredient to your Pantry?",
            isPresented: $showConfirmation
        ) {
            Button("Confirm Move") {
                moveToPantry()
            }
        } message: {
            Text(
                "The purchased grocery entry will be removed after its quantity is added to your Pantry."
            )
        }
        .alert(
            "Unable to Move Ingredient",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func moveToPantry() {
        guard item.isPurchased else {
            errorMessage = "Mark the grocery item as purchased first."
            showError = true
            return
        }

        do {
            let pantryItems = try modelContext.fetch(
                FetchDescriptor<PantryItem>()
            )

            let matchingItem = pantryItems.first { existing in
                existing.name.localizedCaseInsensitiveCompare(
                    item.name
                ) == .orderedSame &&
                existing.unit == item.unit &&
                existing.category == item.category &&
                existing.storageLocation == storage.rawValue &&
                Calendar.current.isDate(
                    existing.expiryDate,
                    inSameDayAs: expiryDate
                )
            }

            if let matchingItem {
                matchingItem.quantity += item.quantity
                matchingItem.updatedAt = Date()
            } else {
                let pantryItem = PantryItem(
                    name: item.name,
                    category: item.category,
                    quantity: item.quantity,
                    unit: item.unit,
                    expiryDate: expiryDate,
                    storageLocation: storage.rawValue
                )

                modelContext.insert(pantryItem)
            }

            modelContext.delete(item)

            try modelContext.save()
            dismiss()

        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
