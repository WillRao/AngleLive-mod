//
//  SearchPageView.swift
//  AngelLiveTVOS2
//
//  搜索页：链接/口令解析、关键词搜索、结果网格与播放。
//

import SwiftUI
import AngelLiveCore

struct SearchPageView: View {
    @Environment(TVAppState.self) private var appState

    @State private var store = SearchStore()
    @State private var player: PlayerPresentation?
    @FocusState private var focus: FocusField?

    private enum FocusField: Hashable {
        case type(Int)
        case input
        case result(Int)
    }

    private let columns = Array(repeating: GridItem(.fixed(380), spacing: 50), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("搜索")
                .font(.system(size: 40, weight: .bold))
                .padding(.horizontal, 92)

            HStack(spacing: 20) {
                ForEach([0, 1], id: \.self) { index in
                    Button {
                        store.searchTypeIndex = index
                    } label: {
                        Text(index == 0 ? "链接/口令" : "关键词")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(store.searchTypeIndex == index ? Color.accentColor : Color.white.opacity(0.15))
                    .focused($focus, equals: .type(index))
                }

                TextField("输入链接/口令或关键词", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .onSubmit { store.submit() }
                    .focused($focus, equals: .input)
                    .frame(maxWidth: 900)
            }
            .padding(.horizontal, 92)

            results
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 60)
        .onChange(of: focus) { _, newValue in
            if case .result(let index) = newValue {
                store.loadMoreIfNeeded(focusedIndex: index)
            }
        }
        .onPlayPauseCommand { store.submit() }
        .onDisappear { store.cancel() }
        .fullScreenCover(item: $player) { item in
            DetailPlayerView { isPresented, _ in
                if !isPresented { player = nil }
            }
            .environment(item.viewModel)
            .environment(appState)
            .frame(width: 1920, height: 1080)
        }
    }

    @ViewBuilder
    private var results: some View {
        if let error = store.error {
            ContentUnavailableView {
                Label("搜索失败", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            } actions: {
                Button("重试") { store.submit() }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.isLoading && store.results.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.results.isEmpty {
            ContentUnavailableView {
                Label("搜索直播", systemImage: "magnifyingglass")
            } description: {
                Text(store.hasSearched ? "没有找到相关直播" : "输入链接/口令或关键词后按确定键搜索")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .center, spacing: 50) {
                    ForEach(Array(store.results.enumerated()), id: \.element.id) { index, room in
                        Button {
                            openRoom(room)
                        } label: {
                            RoomCardView(room: room, isFocused: focus == .result(index))
                        }
                        .buttonStyle(.card)
                        .focused($focus, equals: .result(index))
                    }
                }
                .padding(.horizontal, 92)
            }
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
            enterFromLive: false,
            roomType: .search
        )
        player = PlayerPresentation(viewModel: viewModel)
    }
}
