//
//  HistoryListView.swift
//  AngelLiveTVOS2
//
//  历史记录：最近观看的直播，可直接继续播放。
//

import SwiftUI
import AngelLiveCore

struct HistoryListView: View {
    @Environment(TVAppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var player: PlayerPresentation?
    @FocusState private var focusedIndex: Int?

    private let columns = Array(repeating: GridItem(.fixed(380), spacing: 50), count: 4)

    var body: some View {
        let rooms = appState.historyViewModel.watchList

        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("历史记录")
                    .font(.system(size: 36, weight: .bold))
                Spacer()
                if !rooms.isEmpty {
                    Button("清空") {
                        appState.historyViewModel.clearAll()
                    }
                }
            }
            .padding(.horizontal, 92)
            .padding(.top, 60)

            if rooms.isEmpty {
                ContentUnavailableView {
                    Label("暂无历史记录", systemImage: "clock.arrow.circlepath")
                } description: {
                    Text("观看直播后会自动记录在这里")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .center, spacing: 50) {
                        ForEach(Array(rooms.enumerated()), id: \.element.id) { index, room in
                            Button {
                                openRoom(room)
                            } label: {
                                RoomCardView(room: room, isFocused: focusedIndex == index)
                            }
                            .buttonStyle(.card)
                            .focused($focusedIndex, equals: index)
                        }
                    }
                    .padding(.horizontal, 92)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onExitCommand { dismiss() }
        .fullScreenCover(item: $player) { item in
            DetailPlayerView { isPresented, _ in
                if !isPresented { player = nil }
            }
            .environment(item.viewModel)
            .environment(appState)
            .frame(width: 1920, height: 1080)
        }
    }

    private func openRoom(_ room: LiveModel) {
        WatchCountStore.shared.record(room)
        let viewModel = RoomInfoViewModel(
            currentRoom: room,
            appViewModel: appState,
            enterFromLive: false,
            roomType: .history
        )
        viewModel.roomList = appState.historyViewModel.watchList
        player = PlayerPresentation(viewModel: viewModel)
    }
}
