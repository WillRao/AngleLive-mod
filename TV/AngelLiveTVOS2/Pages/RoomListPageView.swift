//
//  RoomListPageView.swift
//  AngelLiveTVOS2
//
//  房间列表：分类侧栏、分页、播放键刷新、播放器呈现。
//  焦点集中在本页：房间卡片 / 分类按钮 / 侧栏条目。
//

import SwiftUI
import AngelLiveCore

struct RoomListPageView: View {
    let liveType: LiveType

    @Environment(TVAppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var store: RoomListStore
    @State private var isSidebarOpen = false
    @State private var expandedMainIds: Set<String> = []
    @State private var player: PlayerPresentation?
    @FocusState private var focus: FocusField?

    private enum FocusField: Hashable {
        case room(Int)
        case categoryButton
        case sidebarMain(Int)
        case sidebarSub(Int, Int)
    }

    private let columns = Array(repeating: GridItem(.fixed(380), spacing: 50), count: 4)

    init(liveType: LiveType) {
        self.liveType = liveType
        _store = State(initialValue: RoomListStore(liveType: liveType))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Color.black.ignoresSafeArea()
            content

            if isSidebarOpen {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .transition(.opacity)
                sidebar
                    .transition(.move(edge: .leading).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSidebarOpen)
        .task { await store.loadInitialIfNeeded() }
        .onChange(of: focus) { _, newValue in
            guard let newValue else { return }
            switch newValue {
            case .room(let index):
                if isSidebarOpen { isSidebarOpen = false }
                Task { await store.loadMoreIfNeeded(focusedIndex: index) }
            case .sidebarMain, .sidebarSub:
                break
            case .categoryButton:
                break
            }
        }
        .onChange(of: store.rooms.count) { oldValue, newValue in
            if oldValue == 0, newValue > 0, focus == nil {
                focus = .room(0)
            }
        }
        .onExitCommand {
            if isSidebarOpen {
                isSidebarOpen = false
            } else {
                dismiss()
            }
        }
        .onPlayPauseCommand {
            Task { await store.refresh() }
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

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if store.isLoading && store.rooms.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = store.errorMessage, store.rooms.isEmpty {
            ContentUnavailableView {
                Label("加载失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重试") { Task { await store.reloadCategories() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.rooms.isEmpty {
            ContentUnavailableView {
                Label("暂无直播", systemImage: "tv")
            } description: {
                Text("稍后重试或切换分类")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    grid
                }
                .padding(.vertical, 48)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(store.categoryTitle.isEmpty ? LiveParseTools.getLivePlatformName(liveType) : store.categoryTitle)
                .font(.system(size: 32, weight: .bold))

            Spacer()

            Button {
                isSidebarOpen = true
            } label: {
                Label("分类", systemImage: "line.3.horizontal")
                    .font(.system(size: 20, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .focused($focus, equals: .categoryButton)
        }
        .padding(.horizontal, 92)
    }

    private var grid: some View {
        LazyVGrid(columns: columns, alignment: .center, spacing: 50) {
            ForEach(Array(store.rooms.enumerated()), id: \.element.id) { index, room in
                Button {
                    openRoom(room)
                } label: {
                    RoomCardView(room: room, isFocused: focus == .room(index))
                }
                .buttonStyle(.card)
                .focused($focus, equals: .room(index))
                .onMoveCommand { direction in
                    if direction == .left, index % columns.count == 0 {
                        isSidebarOpen = true
                    }
                }
            }
        }
        .padding(.horizontal, 92)
    }

    // MARK: - 分类侧栏

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("分类")
                    .font(.system(size: 24, weight: .bold))
                    .padding(.bottom, 8)

                ForEach(Array(store.categories.enumerated()), id: \.element.id) { mainIndex, main in
                    let isExpanded = expandedMainIds.contains(main.id)

                    Button {
                        toggleExpansion(main.id)
                    } label: {
                        HStack(spacing: 10) {
                            Text(main.title)
                                .font(.system(size: 20, weight: .semibold))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                    }
                    .buttonStyle(.card)
                    .focused($focus, equals: .sidebarMain(mainIndex))

                    if isExpanded {
                        ForEach(Array(main.subList.enumerated()), id: \.element.id) { subIndex, sub in
                            Button {
                                selectCategory(mainIndex: mainIndex, subIndex: subIndex)
                            } label: {
                                HStack(spacing: 10) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isSelected(mainIndex, subIndex) ? Color.accentColor : .clear)
                                        .frame(width: 4, height: 24)
                                    Text(sub.title)
                                        .font(.system(size: 18))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .padding(.leading, 12)
                            }
                            .buttonStyle(.card)
                            .focused($focus, equals: .sidebarSub(mainIndex, subIndex))
                        }
                    }
                }
            }
            .padding(28)
        }
        .frame(width: 420)
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .focusSection()
        .task {
            // 打开侧栏时展开当前分类，并把焦点交给当前子分类（一次性）。
            if store.categories.indices.contains(store.selectedMainIndex) {
                expandedMainIds.insert(store.categories[store.selectedMainIndex].id)
            }
            focus = .sidebarSub(store.selectedMainIndex, store.selectedSubIndex)
        }
    }

    private func toggleExpansion(_ mainId: String) {
        if expandedMainIds.contains(mainId) {
            expandedMainIds.remove(mainId)
        } else {
            expandedMainIds.insert(mainId)
        }
    }

    private func isSelected(_ mainIndex: Int, _ subIndex: Int) -> Bool {
        store.selectedMainIndex == mainIndex && store.selectedSubIndex == subIndex
    }

    private func selectCategory(mainIndex: Int, subIndex: Int) {
        if store.categories.indices.contains(mainIndex) {
            expandedMainIds.insert(store.categories[mainIndex].id)
        }
        isSidebarOpen = false
        Task {
            await store.select(mainIndex: mainIndex, subIndex: subIndex)
            focus = .room(0)
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
        viewModel.roomList = store.rooms
        isSidebarOpen = false
        player = PlayerPresentation(viewModel: viewModel)
    }
}
