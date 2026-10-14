//
//  HomeBasketApp.swift
//  HomeBasket
//
//  Created by STUDENT on 2026-10-13.
//

import SwiftUI
import SwiftData

@main
struct HomeBasketApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(
                    for: [
                        PantryItem.self,
                        GroceryItem.self,
                        MealPlan.self
                    ]
                )
    }
}
