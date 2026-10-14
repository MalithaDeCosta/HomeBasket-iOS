
import SwiftUI

private enum HomeTab: Hashable {
    case home
    case pantry
    case grocery
    case rescue
    case planner
}

struct ContentView: View {

    @State private var selectedTab: HomeTab = .home

    var body: some View {

        TabView(selection: $selectedTab) {

            // MARK: - Home Dashboard

            NavigationStack {

                DashboardView(
                    openPantry: {
                        selectedTab = .pantry
                    },
                    openGrocery: {
                        selectedTab = .grocery
                    },
                    openRescue: {
                        selectedTab = .rescue
                    },
                    openPlanner: {
                        selectedTab = .planner
                    }
                )
            }
            .tabItem {
                Label(
                    "Home",
                    systemImage: "house.fill"
                )
            }
            .tag(HomeTab.home)

            // MARK: - Smart Pantry

            NavigationStack {

                PantryView()
            }
            .tabItem {
                Label(
                    "Pantry",
                    systemImage: "shippingbox.fill"
                )
            }
            .tag(HomeTab.pantry)

            // MARK: - Grocery List and Store Finder

            NavigationStack {

                GroceryView()
                    .toolbar {

                        ToolbarItem(
                            placement: .topBarLeading
                        ) {

                            NavigationLink {

                                GroceryStoreFinderView()

                            } label: {

                                Label(
                                    "Find Stores",
                                    systemImage: "map"
                                )
                            }
                        }
                    }
            }
            .tabItem {
                Label(
                    "Grocery",
                    systemImage: "cart.fill"
                )
            }
            .tag(HomeTab.grocery)

            // MARK: - Smart Food Rescue

            NavigationStack {

                FoodRescueView(
                    openGrocery: {
                        selectedTab = .grocery
                    },
                    openPlanner: {
                        selectedTab = .planner
                    }
                )
            }
            .tabItem {
                Label(
                    "Rescue",
                    systemImage: "leaf.fill"
                )
            }
            .tag(HomeTab.rescue)

            // MARK: - Family Meal Planner

            NavigationStack {

                MealPlannerView()
            }
            .tabItem {
                Label(
                    "Planner",
                    systemImage: "calendar"
                )
            }
            .tag(HomeTab.planner)
        }
        .tint(.green)
    }
}




