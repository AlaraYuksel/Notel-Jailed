//
//  NotelApp.swift
//  Notel
//
//  Created by Alara yüksel on 28.03.2025.
//

import SwiftUI

@main
struct NotelApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
