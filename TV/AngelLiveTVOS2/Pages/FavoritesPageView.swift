//
//  FavoritesPageView.swift
//  AngelLiveTVOS2
//
//  收藏页：本地优先。分组与排序是本页的浏览属性，
//  通过顶部的两个菜单（分组 / 排序）直接切换并记忆选择。
//

import SwiftUI
import AngelLiveCore

enum FavoriteSortMode: Int, CaseIterable, Identifiable {
    case standard = 0
    case popularity = 1
    case watchCount = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .standard: return "默认"
        case .popularity: return "人气"
        case .watchCount: return "观看次数"
        }
    }

    var icon: String {
        switch self {
        case .standard: return "list.bullet"
        case .popularity: return "person.2.fill"
        case .watchCount: return "eye.fill"
        }
    }
}

enum FavoriteGroupMode: Int, CaseIterable, Identifiable {
    case none = 0
    case liveState = 1
    case platform = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "不分组"
        case .liveState: return "按直播状态"
        case .platform: return "按平台"
        }
    }

    var icon: String {
        switch self {
        case .none: return "square.grid.2x2"
        case .liveState: return "dot.radiowaves.left.and.right"
        case .platform: return "square.stack.3d.up.fill"
        }
    }
}

struct FavoritesPageView: View {
    @Environment(TVAppState.self) private var appState
    @State private var player: PlayerPresentation?
    @State private var sortMode: FavoriteSortMode
    @State private var groupMode: FavoriteGroupMode
    @FocusState private var focusedKey: String?

    private let columns = Array(repeating: GridItem(.fixed(380), spacing: 50), count: 4)
    private static let sortKey = "AngelLiveTVOS2.FavoriteSortMode"
    private static let groupKey = "AngelLiveTVOS2.FavoriteGroupMode"

    init() {
        let storedSort = UserDefaults.standard.integer(forKey: Self.sortKey)
        let storedGroup = UserDefaults.standard.integer(forKey: Self.groupKey)
        _sortMode = State(initialValue: FavoriteSortMode(rawValue: storedSort) ?? .standard)
        _groupMode = State(initialValue: FavoriteGroupMode(rawValue: storedGroup) ?? .liveState)
    }

    var body: some View {
        let sections = makeSections()

        VStack(alignment: .leading, spacing: 24) {
            header

            if appState.favoriteViewModel.roomList.isEmpty {
                ContentUnavailableView {
                    Label("暂无收藏", systemImage: "star")
                } description: {
                    Text("在播放页按确定键即可收藏")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        ForEach(sections) { section in
                            if !section.title.isEmpty {
                                HStack(spacing: 12) {
                                    Text(section.title)
                                        .font(.system(size: 26, weight: .bold))
                                    Text("\(section.roomList.count)")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 92)
                            }

                            LazyVGrid(columns: columns, alignment: .center, spacing: 50) {
                                ForEach(section.roomList) { room in
                                    Button {
                                        openRoom(room)
                                    } label: {
                                        RoomCardView(room: room, isFocused: focusedKey == room.id)
                                    }
                                    .buttonStyle(.card)
                                    .focused($focusedKey, equals: room.id)
                                }
                            }
                            .padding(.horizontal, 92)
                        }
                    }
                    .padding(.vertical, 40)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await appState.favoriteViewModel.syncWithActor()
        }
        .fullScreenCover(item: $player) { item in
            DetailPlayerView { isPresented, _ in
                if !isPresented { player = nil }
            }
            .environment(item.viewModel)
            .environment(appState)
            .frame(width: 1920, height: 1080)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text("收藏")
                .font(.system(size: 40, weight: .bold))

            Spacer()

            Menu {
                ForEach(FavoriteGroupMode.allCases) { mode in
                    Button {
                        groupMode = mode
                        UserDefaults.standard.set(mode.rawValue, forKey: Self.groupKey)
                    } label: {
                        if groupMode == mode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Label(groupMode.title, systemImage: groupMode.icon)
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)

            Menu {
                ForEach(FavoriteSortMode.allCases) { mode in
                    Button {
                        sortMode = mode
                        UserDefaults.standard.set(mode.rawValue, forKey: Self.sortKey)
                    } label: {
                        if sortMode == mode {
                            Label(mode.title, systemImage: "checkmark")
                        } else {
                            Text(mode.title)
                        }
                    }
                }
            } label: {
                Label(sortMode.title, systemImage: "arrow.up.arrow.down")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(.horizontal, 92)
        .padding(.top, 60)
    }


    // MARK: - 分组与排序

    private func makeSections() -> [FavoriteLiveSectionModel] {
        let rooms = appState.favoriteViewModel.roomList
        guard !rooms.isEmpty else { return [] }

        var sections: [FavoriteLiveSectionModel]
        switch groupMode {
        case .none:
            var section = FavoriteLiveSectionModel()
            section.roomList = rooms
            sections = [section]
        case .liveState:
            sections = rooms.groupedBySections(style: .liveState)
        case .platform:
            sections = rooms.groupedBySections(style: .section)
        }

        for index in sections.indices {
            sections[index].roomList = sorted(sections[index].roomList)
        }
        return sections
    }

    private func sorted(_ rooms: [LiveModel]) -> [LiveModel] {
        switch sortMode {
        case .standard:
            return rooms
        case .popularity:
            return rooms.sorted { popularity($0) > popularity($1) }
        case .watchCount:
            return rooms.sorted {
                WatchCountStore.shared.count(for: $0) > WatchCountStore.shared.count(for: $1)
            }
        }
    }

    private func popularity(_ room: LiveModel) -> Double {
        guard let raw = room.liveWatchedCount else { return -1 }
        let text = raw.replacingOccurrences(of: ",", with: "")
        if text.hasSuffix("万") || text.hasSuffix("w") || text.hasSuffix("W") {
            return (Double(text.dropLast()) ?? 0) * 10000
        }
        return Double(text) ?? -1
    }

    private func openRoom(_ room: LiveModel) {
        WatchCountStore.shared.record(room)
        if !appState.historyViewModel.watchList.contains(where: { $0.roomId == room.roomId }) {
            appState.historyViewModel.watchList.insert(room, at: 0)
        }
        let viewModel = RoomInfoViewModel(
            currentRoom: room,
            appViewModel: appState,
            enterFromLive: false,
            roomType: .favorite
        )
        viewModel.roomList = appState.favoriteViewModel.roomList
        player = PlayerPresentation(viewModel: viewModel)
    }
}
