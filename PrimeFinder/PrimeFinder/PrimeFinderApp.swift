//
//  PrimeFinderApp.swift
//  PrimeFinder
//
//  Created by Emily Wang on 2024-05-14.
//

import SwiftUI

@main
struct PrimeFinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(store: Store(initialValue: AppState()))
        }
    }
}
