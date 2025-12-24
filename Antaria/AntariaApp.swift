//
//  AntariaApp.swift
//  Antaria
//
//  Created by cmStudent on 2025/12/23.
//

import SwiftUI

@main
struct AntariaApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
