//
//  RoomListStore.swift
//  AngelLiveTVOS2
//
//  房间列表页状态：分类、分页、刷新。页面唯一数据入口，
//  行组件不直接读取本类型。
//

import Foundation
import Observation
import AngelLiveCore

@Observable
@MainActor
final class RoomListStore {
    let liveType: LiveType

    private(set) var categories: [LiveMainListModel] = []
    private(set) var rooms: [LiveModel] = []
    private(set) var categoryTitle = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var hasMore = true
    private(set) var selectedMainIndex = 0
    private(set) var selectedSubIndex = 0

    private var page = 1
    private var generation = UUID()

    init(liveType: LiveType) {
        self.liveType = liveType
    }

    func loadInitialIfNeeded() async {
        guard categories.isEmpty else { return }
        await reloadCategories()
    }

    func reloadCategories() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let list = try await LiveService.fetchCategoryList(liveType: liveType)
            categories = list
            guard let main = list.first, !main.subList.isEmpty else {
                rooms = []
                hasMore = false
                return
            }
            selectedMainIndex = 0
            selectedSubIndex = 0
            await load(page: 1)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func select(mainIndex: Int, subIndex: Int) async {
        guard categories.indices.contains(mainIndex),
              categories[mainIndex].subList.indices.contains(subIndex) else { return }
        selectedMainIndex = mainIndex
        selectedSubIndex = subIndex
        await load(page: 1)
    }

    func refresh() async {
        await load(page: 1)
    }

    func loadMoreIfNeeded(focusedIndex: Int) async {
        guard focusedIndex >= rooms.count - 4, hasMore, !isLoading else { return }
        await load(page: page + 1)
    }

    private func load(page targetPage: Int) async {
        guard categories.indices.contains(selectedMainIndex) else { return }
        let main = categories[selectedMainIndex]
        guard main.subList.indices.contains(selectedSubIndex) else { return }
        let sub = main.subList[selectedSubIndex]

        let generation = UUID()
        self.generation = generation
        isLoading = true
        if targetPage == 1 { errorMessage = nil }
        defer { if self.generation == generation { isLoading = false } }

        do {
            let fetched = try await LiveService.fetchRoomList(
                liveType: liveType,
                category: sub,
                parentBiz: main.biz,
                page: targetPage
            )
            guard self.generation == generation else { return }
            categoryTitle = main.title
            page = targetPage
            if targetPage == 1 {
                rooms = fetched
            } else {
                rooms = rooms.appendingUnique(contentsOf: fetched)
            }
            hasMore = !fetched.isEmpty
        } catch {
            guard self.generation == generation else { return }
            if targetPage == 1 {
                rooms = []
                errorMessage = Self.message(for: error)
            }
        }
    }

    private static func message(for error: Error) -> String {
        (error as? LiveParseError)?.title ?? error.localizedDescription
    }
}
