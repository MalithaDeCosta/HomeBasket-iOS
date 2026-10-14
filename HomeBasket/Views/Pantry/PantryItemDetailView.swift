
import SwiftUI

struct PantryItemDetailView: View {

    let item: PantryItem

    @State private var showEditForm = false

    var body: some View {
        List {
            Section("Ingredient Details") {
                LabeledContent("Name", value: item.name)

                LabeledContent(
                    "Category",
                    value: item.category
                )

                LabeledContent(
                    "Quantity",
                    value: "\(item.quantity.formatted()) \(item.unit)"
                )

                LabeledContent(
                    "Storage",
                    value: item.storageLocation
                )
            }

            Section("Expiry Information") {
                LabeledContent(
                    "Expiry Date",
                    value: item.expiryDate.formatted(
                        date: .abbreviated,
                        time: .omitted
                    )
                )

                LabeledContent(
                    "Status",
                    value: ExpiryService.status(
                        for: item.expiryDate
                    ).title
                )
            }

            Section("Record Information") {
                LabeledContent(
                    "Created",
                    value: item.createdAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )

                LabeledContent(
                    "Last Updated",
                    value: item.updatedAt.formatted(
                        date: .abbreviated,
                        time: .shortened
                    )
                )
            }
        }
        .navigationTitle(item.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showEditForm = true
                }
            }
        }
        .sheet(isPresented: $showEditForm) {
            NavigationStack {
                PantryItemFormView(item: item)
            }
        }
    }
}
