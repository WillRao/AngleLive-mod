//
//  HomeStore.swift
//  AngelLiveTVOS2
//
//  推荐页数据：包装 Core 的插件首页 feed。
//

import Foundation
import Observation
import AngelLiveCore

@Observable
@MainActor
final class HomeStore {
    let model = PluginHomeFeedModel()
    private var didLoad = false

    var banners: [HomeBannerEntry] { model.bannerEntries }
    var sections: [HomeSectionEntry] { model.sectionEntries }
    var failedPlugins: [String] { model.failedPluginNames }
    var isRefreshing: Bool { model.isRefreshing }

    func loadIfNeeded(installedPluginIds: [String], availabilityConfirmed: Bool) async {
        guard !didLoad else { return }
        didLoad = true
        let context = await PluginHomeFeedRefreshContext.current(for: installedPluginIds)
        await model.refresh(
            installedPluginIds: installedPluginIds,
            availabilityConfirmed: availabilityConfirmed,
            context: context
        )
    }

    func refresh(installedPluginIds: [String], availabilityConfirmed: Bool) async {
        let context = await PluginHomeFeedRefreshContext.current(for: installedPluginIds)
        await model.refresh(
            installedPluginIds: installedPluginIds,
            availabilityConfirmed: availabilityConfirmed,
            context: context,
            force: true
        )
    }
}
