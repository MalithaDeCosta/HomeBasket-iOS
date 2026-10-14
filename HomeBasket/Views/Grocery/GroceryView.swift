
import SwiftUI
import SwiftData

struct GroceryView: View {

    @Environment(\.modelContext) private var modelContext

    @Query(sort: \GroceryItem.createdAt, order: .reverse)
    private var groceryItems: [GroceryItem]

    @State private var searchText = ""
    @State private var selectedCategory = "All"

    @State private var activeSheet: GrocerySheet?

    @State private var showError = false
    @State private var errorMessage = ""

    private enum GrocerySheet: Identifiable {
        case add
        case edit(GroceryItem)
        case transfer(GroceryItem)

        var id: String {
            switch self {
            case .add:
                return "add"
            case .edit(let item):
                return "edit-\(item.id.uuidString)"
            case .transfer(let item):
                return "transfer-\(item.id.uuidString)"
            }
        }
    }

    private var filteredItems: [GroceryItem] {
        groceryItems.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(
                    searchText
                )

            let matchesCategory = selectedCategory == "All" ||
                item.category == selectedCategory

            return matchesSearch && matchesCategory
        }
    }

    private var pendingItems: [GroceryItem] {
        filteredItems.filter { !$0.isPurchased }
    }

    private var purchasedItems: [GroceryItem] {
        filteredItems.filter { $0.isPurchased }
    }

    var body: some View {
        List {

            Section("Shopping Filters") {
                Picker("Category", selection: $selectedCategory) {
                    Text("All").tag("All")

                    ForEach(PantryCategory.allCases) { category in
                        Text(category.rawValue)
                            .tag(category.rawValue)
                    }
                }
            }

            if groceryItems.isEmpty {
                ContentUnavailableView(
                    "Your Shopping List Is Empty",
                    systemImage: "cart",
                    description: Text(
                        "Tap + to add your first grocery item."
                    )
                )
            } else if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Matching Groceries",
                    systemImage: "magnifyingglass",
                    description: Text(
                        "Try changing your search or category."
                    )
                )
            } else {

                Section("To Buy (\(pendingItems.count))") {

                    if pendingItems.isEmpty {
                        Text("No pending items.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(pendingItems) { item in
                        groceryRow(for: item)
                    }
                }

                Section("Purchased (\(purchasedItems.count))") {

                    if purchasedItems.isEmpty {
                        Text("No purchased items yet.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(purchasedItems) { item in
                        groceryRow(for: item)
                    }
                }
            }
        }
        .navigationTitle("Grocery Shopping")
        .searchable(
            text: $searchText,
            prompt: "Search groceries"
        )
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    activeSheet = .add
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add grocery item")
            }
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                switch sheet {
                case .add:
                    GroceryItemFormView()

                case .edit(let item):
                    GroceryItemFormView(item: item)

                case .transfer(let item):
                    GroceryTransferView(item: item)
                }
            }
        }
        .alert(
            "Grocery Update Failed",
            isPresented: $showError
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func groceryRow(
        for item: GroceryItem
    ) -> some View {

        HStack(spacing: 12) {

            Button {
                togglePurchased(item)
            } label: {
                Image(
                    systemName: item.isPurchased
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title2)
                .foregroundStyle(
                    item.isPurchased ? .green : .gray
                )
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(
                item.isPurchased
                    ? "Mark as not purchased"
                    : "Mark as purchased"
            )

            VStack(alignment: .leading, spacing: 5) {

                Text(item.name)
                    .font(.headline)
                    .strikethrough(item.isPurchased)
                    .foregroundStyle(
                        item.isPurchased
                            ? .secondary
                            : .primary
                    )

                Text(
                    "\(item.quantity.formatted()) \(item.unit) • \(item.category)"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button {
                    activeSheet = .edit(item)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                if item.isPurchased {
                    Button {
                        activeSheet = .transfer(item)
                    } label: {
                        Label(
                            "Move to Pantry",
                            systemImage: "shippingbox"
                        )
                    }
                }

                Button(role: .destructive) {
                    deleteGrocery(item)
                } label: {
                    Label("Delete", systemImage: "trash")
                }

            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Options for \(item.name)")
        }
        .padding(.vertical, 5)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {

            Button("Delete", role: .destructive) {
                deleteGrocery(item)
            }

            Button("Edit") {
                activeSheet = .edit(item)
            }
            .tint(.blue)
        }
    }

    private func togglePurchased(
        _ item: GroceryItem
    ) {

        if item.isPurchased {
            let duplicate = groceryItems.contains { other in
                other.id != item.id &&
                !other.isPurchased &&
                other.name.localizedCaseInsensitiveCompare(
                    item.name
                ) == .orderedSame &&
                other.unit == item.unit &&
                other.category == item.category
            }

            if duplicate {
                errorMessage = "This item already exists in your pending list."
                showError = true
                return
            }
        }

        item.isPurchased.toggle()
        item.updatedAt = Date()

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteGrocery(
        _ item: GroceryItem
    ) {
        modelContext.delete(item)

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
