//
//  MainTabView.swift
//  AppOptimizer
//
//  Created by Alsu Faizova on 09.06.2025.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var settings = SettingsModel()
    @State private var appPath: String = ""

    var body: some View {
        TabView {
            HomeView(appPath: $appPath, settings: settings)
                .tabItem { Label("Главная", systemImage: "house") }

            SettingsView(projectRoot: $appPath, settings: settings)
                .tabItem { Label("Настройки", systemImage: "gear") }
        }
        .frame(minWidth: 820, minHeight: 640)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}
