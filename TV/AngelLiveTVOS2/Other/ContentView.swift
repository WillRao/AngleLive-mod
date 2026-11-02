//
//  ContentView.swift
//  AngelLiveTVOS2
//
//  根导航：系统 TabView（tvOS 原生侧栏）。
//

import SwiftUI
import AngelLiveCore

struct ContentView: View {
    @Environment(TVAppState.self) private var appState
    @AppStorage("SimpleLive.Setting.ShowHomeRecommendation") private var showHomeRecommendation = true
    @State private var selection = 0

    private var showsHome: Bool {
        showHomeRecommendation && appState.pluginAvailability.hasAvailablePlugins
    }

    var body: some View {
        TabView(selection: $selection) {
            if showsHome {
                HomePageView()
                    .tabItem { Label("推荐", systemImage: "house.fill") }
                    .tag(0)
            }

            FavoritesPageView()
                .tabItem { Label("收藏", systemImage: "star.fill") }
                .tag(1)

            PlatformPageView()
                .tabItem { Label("平台", systemImage: "square.stack.3d.up.fill") }
                .tag(2)

            SearchPageView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                .tag(3)

            SettingsPageView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(4)
        }
        .task {
            await appState.pluginAvailability.checkAvailability()
        }
        .task(id: showsHome) {
            if !showsHome, selection == 0 {
                selection = 1
            }
        }
    }
}
