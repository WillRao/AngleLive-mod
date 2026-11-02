//
//  SearchStore.swift
//  AngelLiveTVOS2
//
//  搜索页数据：包装 Core 的 SearchRequestModel。
//

import Foundation
import Observation
import AngelLiveCore

@Observable
@MainActor
final class SearchStore {
    let request = SearchRequestModel(fetchOutcome: SearchStore.fetchOutcome)

    var searchTypeIndex = 0
    var searchText = ""

    var results: [LiveModel] { request.rooms }
    var isLoading: Bool { request.isLoading }
    var error: Error? { request.error }
    var hasMore: Bool { request.hasMore }
    var hasSearched: Bool { request.hasSearched }

    func submit() {
        let input = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            request.clear()
            return
        }
        request.submit(input: input, kind: searchTypeIndex == 1 ? .keyword : .share)
    }

    func loadMoreIfNeeded(focusedIndex: Int) {
        guard focusedIndex >= results.count - 4 else { return }
        request.loadMore()
    }

    func cancel() {
        request.cancel()
    }

    private static func fetchOutcome(_ request: RoomSearchRequest) async throws -> RoomSearchOutcome {
        switch request.kind {
        case .keyword:
            return try await LiveService.searchRoomsWithOutcome(keyword: request.input, page: request.page)
        case .share:
            return try await LiveService.searchRoomWithShareCodeWithOutcome(shareCode: request.input)
        }
    }
}
