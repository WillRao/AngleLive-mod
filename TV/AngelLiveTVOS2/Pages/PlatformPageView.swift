//
//  PlatformPageView.swift
//  AngelLiveTVOS2
//
//  平台页：使用插件提供的平台大图/图标，聚焦时显示平台描述。
//

import SwiftUI
import AngelLiveCore
import AngelLiveDependencies

struct PlatformPageView: View {
    @Environment(TVAppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var platforms: [LiveParseJSPlatform] = []
    @State private var selected: SelectedPlatform?
    @FocusState private var focusedIndex: Int?

    private let columns = Array(repeating: GridItem(.fixed(380), spacing: 50), count: 4)

    private struct SelectedPlatform: Identifiable {
        let liveType: LiveType
        var id: String { liveType.rawValue }
    }

    var body: some View {
        Group {
            if platforms.isEmpty {
                ContentUnavailableView {
                    Label("暂无可用平台", systemImage: "square.stack.3d.up")
                } description: {
                    Text("安装插件后，平台会显示在这里")
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 50) {
                        ForEach(Array(platforms.enumerated()), id: \.element.pluginId) { index, platform in
                            Button {
                                if let liveType = platform.liveTypes.first {
                                    selected = SelectedPlatform(liveType: liveType)
                                }
                            } label: {
                                platformCard(platform, isFocused: focusedIndex == index)
                            }
                            .buttonStyle(.card)
                            .focused($focusedIndex, equals: index)
                        }
                    }
                    .padding(92)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await reload() }
        .onChange(of: appState.pluginAvailability.installedPluginIds) { _, _ in
            Task { await reload() }
        }
        .fullScreenCover(item: $selected) { item in
            RoomListPageView(liveType: item.liveType)
                .environment(appState)
        }
    }

    private func platformCard(_ platform: LiveParseJSPlatform, isFocused: Bool) -> some View {
        ZStack(alignment: .bottomLeading) {
            // 平台大图（插件提供）；缺失时用渐变色兜底
            if let bigImage = TVPlatformIconProvider.bigCardImage(for: cardModel(platform), isDarkMode: colorScheme == .dark) {
                Image(uiImage: bigImage)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.white.opacity(0.16), Color.white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // 底部遮罩，保证文字可读
            LinearGradient(
                colors: [.clear, .black.opacity(0.78)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName(platform))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                if isFocused, let description = platform.platformDescription, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                }
            }
            .padding(20)
        }
        .frame(width: 370, height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isFocused ? 1.03 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }

    private func cardModel(_ platform: LiveParseJSPlatform) -> Platformdescription {
        Platformdescription(
            title: displayName(platform),
            pluginId: platform.pluginId,
            bigPic: "tv_\(platform.pluginId)_big",
            smallPic: "tv_\(platform.pluginId)_small",
            descripiton: platform.platformDescription ?? "",
            liveType: platform.liveTypes.first ?? .placeholder
        )
    }

    private func displayName(_ platform: LiveParseJSPlatform) -> String {
        if let name = platform.platformName, !name.isEmpty {
            return name
        }
        guard let liveType = platform.liveTypes.first else {
            return platform.pluginId
        }
        return LiveParseTools.getLivePlatformName(liveType)
    }

    private func reload() async {
        await appState.pluginAvailability.checkAvailability()
        platforms = SandboxPluginCatalog.availablePlatforms(
            installedPluginIds: appState.pluginAvailability.installedPluginIds
        )
    }
}
