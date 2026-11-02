//
//  AngelLiveTVOS2App.swift
//  AngelLiveTVOS2
//
//  重写版 tvOS 宿主入口（P1 骨架）。
//  设计目标：轻量、流畅、原生。共享能力全部来自 AngelLiveCore / AngelLiveDependencies，
//  宿主只负责页面、焦点与呈现。
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

@main
struct AngelLiveTVOS2App: App {
    @State private var appState = TVAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}
