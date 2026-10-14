
import SwiftUI
import MapKit

// MARK: - Search Presets

private enum GrocerySearchArea: String, CaseIterable, Identifiable {
    case colombo = "Colombo"
    case kandy = "Kandy"
    case galle = "Galle"
    case cupertino = "Cupertino"

    var id: String { rawValue }

    var region: MKCoordinateRegion {
        let center: CLLocationCoordinate2D

        switch self {
        case .colombo:
            center = CLLocationCoordinate2D(
                latitude: 6.9271,
                longitude: 79.8612
            )

        case .kandy:
            center = CLLocationCoordinate2D(
                latitude: 7.2906,
                longitude: 80.6337
            )

        case .galle:
            center = CLLocationCoordinate2D(
                latitude: 6.0535,
                longitude: 80.2210
            )

        case .cupertino:
            center = CLLocationCoordinate2D(
                latitude: 37.3230,
                longitude: -122.0322
            )
        }

        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: 0.075,
                longitudeDelta: 0.075
            )
        )
    }
}

// MARK: - Search Categories

private enum GrocerySearchCategory: String, CaseIterable, Identifiable {
    case supermarkets = "Supermarkets"
    case groceryStores = "Grocery Stores"
    case foodMarkets = "Food Markets"

    var id: String { rawValue }

    var searchText: String {
        switch self {
        case .supermarkets:
            return "supermarket"

        case .groceryStores:
            return "grocery store"

        case .foodMarkets:
            return "food market"
        }
    }
}

// MARK: - Store Search Result

private struct GroceryStoreSearchResult: Identifiable {

    let id = UUID()
    let mapItem: MKMapItem

    var name: String {
        mapItem.name ?? "Unnamed Grocery Store"
    }

    var coordinate: CLLocationCoordinate2D {
        mapItem.placemark.coordinate
    }

    var address: String {
        mapItem.placemark.title ?? "Address unavailable"
    }

    func distanceKilometers(
        from center: CLLocationCoordinate2D
    ) -> Double {

        let source = CLLocation(
            latitude: center.latitude,
            longitude: center.longitude
        )

        let destination = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        return source.distance(from: destination) / 1000
    }
}

// MARK: - Grocery Store Finder

struct GroceryStoreFinderView: View {

    // MARK: Search Selections

    @State private var selectedArea:
        GrocerySearchArea = .colombo

    @State private var selectedCategory:
        GrocerySearchCategory = .supermarkets

    // MARK: Map Camera

    @State private var cameraPosition:
        MapCameraPosition = .region(
            GrocerySearchArea.colombo.region
        )

    @State private var searchedRegion =
        GrocerySearchArea.colombo.region

    // MARK: Store Results

    @State private var stores:
        [GroceryStoreSearchResult] = []

    @State private var selectedStore:
        GroceryStoreSearchResult?

    // MARK: Search State

    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var searchError: String?

    @State private var searchTask:
        Task<Void, Never>?

    @State private var activeSearchID = UUID()

    // MARK: Main View

    var body: some View {

        ScrollView {

            VStack(
                alignment: .leading,
                spacing: 18
            ) {

                // MARK: Header

                VStack(
                    alignment: .leading,
                    spacing: 6
                ) {

                    Label(
                        "Explore Grocery Stores",
                        systemImage: "map.fill"
                    )
                    .font(.title3.bold())
                    .foregroundStyle(.green)

                    Text(
                        "Find real shops using Apple Maps. Choose a city, or move the map and search the visible area."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                // MARK: Search Options

                VStack(spacing: 12) {

                    Picker(
                        "Demo City",
                        selection: $selectedArea
                    ) {

                        ForEach(
                            GrocerySearchArea.allCases
                        ) { area in

                            Text(area.rawValue)
                                .tag(area)
                        }
                    }
                    .onChange(of: selectedArea) {
                        _, area in

                        cameraPosition = .region(
                            area.region
                        )

                        beginSearch(
                            in: area.region
                        )
                    }

                    Picker(
                        "Looking For",
                        selection: $selectedCategory
                    ) {

                        ForEach(
                            GrocerySearchCategory.allCases
                        ) { category in

                            Text(category.rawValue)
                                .tag(category)
                        }
                    }
                    .onChange(of: selectedCategory) {
                        _, _ in

                        beginSearch(
                            in: cameraPosition.region
                                ?? selectedArea.region
                        )
                    }
                }
                .padding(14)
                .background(
                    Color(
                        .secondarySystemGroupedBackground
                    ),
                    in: RoundedRectangle(
                        cornerRadius: 16
                    )
                )

                // MARK: Interactive Map

                Map(position: $cameraPosition) {

                    ForEach(stores) { store in

                        Marker(
                            store.name,
                            systemImage: "cart.fill",
                            coordinate: store.coordinate
                        )
                        .tint(.green)
                    }
                }
                .frame(height: 320)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 18
                    )
                )
                .overlay {

                    RoundedRectangle(
                        cornerRadius: 18
                    )
                    .strokeBorder(
                        .green.opacity(0.15),
                        lineWidth: 1
                    )
                }
                .accessibilityLabel(
                    "Map of grocery store search results"
                )

                // MARK: Search Visible Area

                Button {

                    beginSearch(
                        in: cameraPosition.region
                            ?? selectedArea.region
                    )

                } label: {

                    Label(
                        "Search This Map Area",
                        systemImage: "magnifyingglass"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(isSearching)

                Text(
                    "Distance labels are straight-line estimates from the searched map center, not driving distances or your GPS location."
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                // MARK: Result Count

                HStack {

                    Text("Search Results")
                        .font(.headline)

                    Spacer()

                    if !isSearching &&
                        hasSearched &&
                        searchError == nil {

                        Text("\(stores.count) found")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: Search Results

                if isSearching {

                    HStack(spacing: 10) {

                        ProgressView()

                        Text(
                            "Searching Apple Maps..."
                        )
                        .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)

                } else if let searchError {

                    ContentUnavailableView(
                        "Search Unavailable",
                        systemImage: "wifi.exclamationmark",
                        description: Text(
                            searchError +
                            " Try another city or check the simulator's internet connection."
                        )
                    )

                } else if hasSearched &&
                            stores.isEmpty {

                    ContentUnavailableView(
                        "No Stores Found",
                        systemImage: "magnifyingglass",
                        description: Text(
                            "Try another search category or select Cupertino as a demonstration area."
                        )
                    )

                } else {

                    ForEach(stores) { store in

                        Button {

                            selectedStore = store

                            cameraPosition = .region(
                                MKCoordinateRegion(
                                    center: store.coordinate,
                                    span: MKCoordinateSpan(
                                        latitudeDelta: 0.015,
                                        longitudeDelta: 0.015
                                    )
                                )
                            )

                        } label: {

                            storeRow(store)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(
            Color(.systemGroupedBackground)
        )
        .navigationTitle("Find Grocery Stores")
        .navigationBarTitleDisplayMode(.inline)

        // MARK: Store Details Sheet

        .sheet(item: $selectedStore) { store in

            GroceryStoreDetailView(
                store: store,
                referenceCenter: searchedRegion.center
            )
        }

        // MARK: Initial Search

        .task {
            beginSearch(
                in: selectedArea.region
            )
        }

        .onDisappear {
            searchTask?.cancel()
        }
    }

    // MARK: - Store Result Row

    private func storeRow(
        _ store: GroceryStoreSearchResult
    ) -> some View {

        HStack(
            alignment: .top,
            spacing: 12
        ) {

            Image(systemName: "basket.fill")
                .font(.title3)
                .foregroundStyle(.green)
                .frame(width: 30)

            VStack(
                alignment: .leading,
                spacing: 5
            ) {

                Text(store.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)

                Text(store.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(
                    String(
                        format: "Approx. %.1f km from map center",
                        store.distanceKilometers(
                            from: searchedRegion.center
                        )
                    )
                )
                .font(.caption2)
                .foregroundStyle(.green)
            }

            Spacer(minLength: 4)

            Image(
                systemName: "chevron.right"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(
                cornerRadius: 14
            )
        )
        .accessibilityElement(
            children: .combine
        )
    }

    // MARK: - Live MapKit Search

    private func beginSearch(
        in region: MKCoordinateRegion
    ) {

        searchTask?.cancel()

        let requestID = UUID()

        activeSearchID = requestID
        searchedRegion = region

        isSearching = true
        hasSearched = true

        searchError = nil
        stores = []

        let query = selectedCategory.searchText

        searchTask = Task { @MainActor in

            let request = MKLocalSearch.Request()

            request.naturalLanguageQuery = query
            request.region = region
            request.resultTypes = .pointOfInterest

            let search = MKLocalSearch(
                request: request
            )

            do {

                let response = try await search.start()

                guard !Task.isCancelled,
                      activeSearchID == requestID else {
                    return
                }

                stores = response.mapItems
                    .map {
                        GroceryStoreSearchResult(
                            mapItem: $0
                        )
                    }
                    .sorted {

                        $0.distanceKilometers(
                            from: region.center
                        )
                        <
                        $1.distanceKilometers(
                            from: region.center
                        )
                    }

            } catch {

                guard !Task.isCancelled,
                      activeSearchID == requestID else {
                    return
                }

                searchError =
                    error.localizedDescription
            }

            if activeSearchID == requestID {
                isSearching = false
            }
        }
    }
}

// MARK: - Store Details Sheet

private struct GroceryStoreDetailView: View {

    @Environment(\.dismiss)
    private var dismiss

    let store: GroceryStoreSearchResult
    let referenceCenter: CLLocationCoordinate2D

    var body: some View {

        NavigationStack {

            ScrollView {

                VStack(
                    alignment: .leading,
                    spacing: 18
                ) {

                    // MARK: Store Name

                    Label(
                        store.name,
                        systemImage: "basket.fill"
                    )
                    .font(.title2.bold())
                    .foregroundStyle(.green)

                    // MARK: Store Address

                    Label(
                        store.address,
                        systemImage: "mappin.and.ellipse"
                    )
                    .font(.subheadline)

                    // MARK: Distance

                    Label(
                        String(
                            format: "Approx. %.1f km from searched map center",
                            store.distanceKilometers(
                                from: referenceCenter
                            )
                        ),
                        systemImage: "point.topleft.down.to.point.bottomright.curvepath"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    // MARK: Phone Number

                    if let phone =
                        store.mapItem.phoneNumber,
                       !phone.isEmpty {

                        Label(
                            phone,
                            systemImage: "phone"
                        )
                    }

                    // MARK: Website

                    if let website =
                        store.mapItem.url {

                        Link(destination: website) {

                            Label(
                                "Visit Store Website",
                                systemImage: "globe"
                            )
                        }
                    }

                    // MARK: Apple Maps Directions

                    Button {

                        store.mapItem.openInMaps(
                            launchOptions: [
                                MKLaunchOptionsDirectionsModeKey:
                                    MKLaunchOptionsDirectionsModeDriving
                            ]
                        )

                    } label: {

                        Label(
                            "Directions in Apple Maps",
                            systemImage: "arrow.triangle.turn.up.right.diamond.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Text(
                        "Store availability, opening hours and routing depend on Apple's current map data. Opening directions may switch to the Maps app."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .padding()
            }
            .navigationTitle("Store Details")
            .navigationBarTitleDisplayMode(.inline)

            .toolbar {

                ToolbarItem(
                    placement: .topBarTrailing
                ) {

                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents(
            [.medium, .large]
        )
    }
}
