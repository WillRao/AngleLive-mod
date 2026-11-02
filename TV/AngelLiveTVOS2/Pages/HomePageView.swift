//
//  HomePageView.swift
//  AngelLiveTVOS2
//
//  推荐页：插件首页 feed（轮播 + 分区横排）。
//

import SwiftUI
import AngelLiveCore

struct HomePageView: View {
    @Environment(TVAppState.self) private var appState

    @State private var store = HomeStore()
    @State private var player: PlayerPresentation?
    @State private var platformRoute: PlatformRoute?
    @FocusState private var focus: FocusField?

    private enum FocusField: Hashable {
        case banner
        case rail(Int, Int)
    }

    private struct PlatformRoute: Identifiable {
        let liveType: LiveType
        var id: String { liveType.rawValue }
    }

    var body: some View {
        Group {
            if !appState.pluginAvailability.hasAvailablePlugins {
                ContentUnavailableView {
                    Label("未安装插件", systemImage: "puzzlepiece.extension")
                } description: {
                    Text("安装插件后，这里会显示推荐内容")
                }
            } else if store.banners.isEmpty && store.sections.isEmpty {
                if store.isRefreshing {
                    ProgressView()
                } else {
                    ContentUnavailableView {
                        Label("暂无推荐内容", systemImage: "house")
                    } description: {
                        Text("插件暂未提供首页内容，可先到「平台」浏览直播")
                    }
                }
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await appState.pluginAvailability.checkAvailability()
            await store.loadIfNeeded(
                installedPluginIds: appState.pluginAvailability.installedPluginIds,
                availabilityConfirmed: appState.pluginAvailability.hasCheckedAvailability
            )
        }
        .onChange(of: appState.pluginAvailability.hasCheckedAvailability) { _, _ in
            Task {
                await store.refresh(
                    installedPluginIds: appState.pluginAvailability.installedPluginIds,
                    availabilityConfirmed: appState.pluginAvailability.hasCheckedAvailability
                )
            }
        }
        .onChange(of: appState.pluginAvailability.installedPluginIds) { _, _ in
            Task {
                await store.refresh(
                    installedPluginIds: appState.pluginAvailability.installedPluginIds,
                    availabilityConfirmed: appState.pluginAvailability.hasCheckedAvailability
                )
            }
        }
        .onPlayPauseCommand {
            Task {
                await store.refresh(
                    installedPluginIds: appState.pluginAvailability.installedPluginIds,
                    availabilityConfirmed: appState.pluginAvailability.hasCheckedAvailability
                )
            }
        }
        .fullScreenCover(item: $player) { item in
            DetailPlayerView { isPresented, _ in
                if !isPresented { player = nil }
            }
            .environment(item.viewModel)
            .environment(appState)
            .frame(width: 1920, height: 1080)
        }
        .fullScreenCover(item: $platformRoute) { route in
            RoomListPageView(liveType: route.liveType)
                .environment(appState)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                if let banner = store.banners.first {
                    bannerCard(banner)
                }

                ForEach(Array(store.sections.enumerated()), id: \.element.id) { sectionIndex, entry in
                    sectionView(entry, sectionIndex: sectionIndex)
                }

                if !store.failedPlugins.isEmpty {
                    Text("部分内容加载失败：\(store.failedPlugins.joined(separator: "、"))")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 92)
                }
            }
            .padding(.vertical, 60)
        }
    }

    private func bannerCard(_ entry: HomeBannerEntry) -> some View {
        Button {
            openBanner(entry)
        } label: {
            ZStack(alignment: .bottomLeading) {
                CoverImage(url: entry.banner.imageURL?.absoluteString ?? "", pixelSize: CGSize(width: 1920, height: 1080))
                    .frame(height: 420)
                    .frame(maxWidth: .infinity)
                    .clipped()

                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.pluginDisplayName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                    Text(entry.banner.title)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    if let subtitle = entry.banner.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                    }
                }
                .padding(48)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .scaleEffect(focus == .banner ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: focus == .banner)
        }
        .buttonStyle(.card)
        .focused($focus, equals: .banner)
        .padding(.horizontal, 92)
    }

    private func sectionView(_ entry: HomeSectionEntry, sectionIndex: Int) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(entry.section.title)
                    .font(.system(size: 26, weight: .bold))
                if let subtitle = entry.section.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 92)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 36) {
                    ForEach(Array(entry.section.items.enumerated()), id: \.element.id) { itemIndex, item in
                        Button {
                            openRoom(item.room)
                        } label: {
                            RoomCardView(room: item.room, isFocused: focus == .rail(sectionIndex, itemIndex))
                        }
                        .buttonStyle(.card)
                        .focused($focus, equals: .rail(sectionIndex, itemIndex))
                        .frame(width: 370)
                    }
                }
                .padding(.horizontal, 92)
            }
            .scrollClipDisabled()
        }
    }

    private func openBanner(_ entry: HomeBannerEntry) {
        switch entry.banner.target {
        case .room(let room):
            openRoom(room)
        case .category:
            platformRoute = PlatformRoute(liveType: entry.liveType)
        }
    }

    private func openRoom(_ room: LiveModel) {
        WatchCountStore.shared.record(room)
        if !appState.historyViewModel.watchList.contains(where: { $0.roomId == room.roomId }) {
            appState.historyViewModel.watchList.insert(room, at: 0)
        }
        let viewModel = RoomInfoViewModel(
            currentRoom: room,
            appViewModel: appState,
            enterFromLive: true,
            roomType: .live
        )
        player = PlayerPresentation(viewModel: viewModel)
    }
}
