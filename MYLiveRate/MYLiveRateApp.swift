//
//  MYLiveRateApp.swift
//  MYLiveRate
//
//  Created by zy on 2026/4/30.
//

import SwiftUI
import SwiftData

@main
struct MYLiveRateApp: App {
    private let localRecordsStore = LocalRecordsStore.shared

    var body: some Scene {
        WindowGroup {
            AuthGateView()
                .modelContainer(localRecordsStore.container)
        }
    }
}
