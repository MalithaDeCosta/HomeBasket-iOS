
import SwiftUI
import SwiftData

struct PantryView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \PantryItem.expiryDate)
    private var pantryItems: [PantryItem]

    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var sortByName = false
    @State private var showAddForm = false

    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""

    private var visibleItems: [PantryItem] {
        let filtered = pantryItems.filter { item in

            let matchesSearch = searchText.isEmpty
                || item.name.localizedCaseInsensitiveContains(
                    searchText
                )

            let matchesCategory = selectedCategory == "All"
                || item.category == selectedCategory

            return matchesSearch && matchesCategory
        }

        if sortByName {
            return filtered.sorted {
                $0.name.localizedStandardCompare(
                    $1.name
                ) == .orderedAscending
            }
        }

        return filtered.sorted {
            $0.expiryDate < $1.expiryDate
        }
    }

    var body: some View {
        List {

            Section("Filter and Sort") {

                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("All")

                    ForEach(PantryCategory.allCases) { category in
                        Text(category.rawValue)
                            .tag(category.rawValue)
                    }
                }

                Picker("Sort By", selection: $sortByName) {
                    Text("Expiry Date").tag(false)
                    Text("Name").tag(true)
                }
            }

            Section {
                if visibleItems.isEmpty {
                    ContentUnavailableView(
                        "No Ingredients Found",
                        systemImage: "shippingbox",
                        description: Text(
                            pantryItems.isEmpty
                            ? "Tap + to add your first ingredient."
                            : "Try changing your search or category."
                        )
                    )
                } else {
                    ForEach(visibleItems) { item in
                        NavigationLink {
                            PantryItemDetailView(item: item)
                        } label: {
                            pantryRow(for: item)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            } header: {
                Text("Ingredients (\(visibleItems.count))")
            }
        }
        .navigationTitle("Smart Pantry")
        .searchable(
            text: $searchText,
            prompt: "Search ingredients"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddForm = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add ingredient")
            }
        }
        .sheet(isPresented: $showAddForm) {
            NavigationStack {
                PantryItemFormView()
            }
        }
        .alert(
            "Unable to Delete",
            isPresented: $showDeleteError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private func pantryRow(
        for item: PantryItem
    ) -> some View {

        let status = ExpiryService.status(
            for: item.expiryDate
        )

        return HStack(spacing: 12) {

            Image(systemName: "shippingbox.fill")
                .font(.title2)
                .foregroundStyle(.green)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 5) {

                Text(item.name)
                    .font(.headline)

                Text(
                    "\(item.quantity.formatted()) \(item.unit) • \(item.storageLocation)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {

                Text(status.title)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(
                        color(for: status)
                    )

                Text(
                    item.expiryDate,
                    format: .dateTime.day().month()
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 5)
    }

    private func color(
        for status: ExpiryStatus
    ) -> Color {
        switch status {
        case .expired:
            return .red
        case .expiringSoon:
            return .orange
        case .fresh:
            return .green
        }
    }

    private func deleteItems(
        at offsets: IndexSet
    ) {
        for index in offsets {
            let item = visibleItems[index]
            modelContext.delete(item)
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
