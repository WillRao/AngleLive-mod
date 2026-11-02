//
//  TVAppState.swift
//  AngelLiveTVOS2
//
//  宿主级服务容器。只持有 Core 服务，不承载页面状态；
//  页面各自拥有独立 Store，行组件只接收自己的数据。
//

import Foundation
import Observation
import AngelLiveCore
import AngelLiveDependencies

@Observable
final class TVAppState {

    let favoriteViewModel = AppFavoriteModel()
    let historyViewModel = HistoryModel()
    let pluginAvailability = PluginAvailabilityService(managesAPICredentialPolicy: true)

    @ObservationIgnored lazy var pluginSourceManager = PluginSourceManager()
    @ObservationIgnored lazy var consentService = PluginInstallConsentService()
    @ObservationIgnored lazy var generalSettingsViewModel = GeneralSettingModel()
    @ObservationIgnored lazy var danmuSettingsViewModel = DanmuSettingModel()
    @ObservationIgnored lazy var playerSettingsViewModel = PlayerSettingModel()
    // 端口与旧宿主错开，避免两套 App 同时运行时端口冲突导致服务起不来。
    @ObservationIgnored lazy var remoteInputService = RemoteInputService(port: 8081)

    init() {
        _ = pluginSourceManager
        _ = consentService
        _ = generalSettingsViewModel
        _ = danmuSettingsViewModel
        _ = playerSettingsViewModel
        remoteInputService.start()
        pluginSourceManager.consentRequester = consentService
        wireRemoteFavoritesBackup()
    }

    // MARK: - 收藏导入确认

    struct PendingFavoriteImport: Identifiable {
        let id = UUID()
        let rooms: [LiveModel]
        let failures: Int
    }

    /// 手机端提交备份后，在导入页面里选择合并或覆盖。
    var pendingFavoriteImport: PendingFavoriteImport?
    /// 导入过程与结果文案，直接显示在导入页面上。
    var favoriteImportStatus: String?

    private var importContinuation: CheckedContinuation<Bool?, Never>?

    /// 挂起等待电视端选择（合并 = true，覆盖 = false，取消 = nil）。
    /// 浏览器请求会一直等到用户选择，再拿到真实结果。
    func requestFavoriteImport(rooms: [LiveModel], failures: Int) async -> Bool? {
        await withCheckedContinuation { continuation in
            importContinuation = continuation
            pendingFavoriteImport = PendingFavoriteImport(rooms: rooms, failures: failures)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 120_000_000_000)
                guard let self, self.importContinuation != nil else { return }
                self.resolveFavoriteImport(merge: nil)
            }
        }
    }

    func resolveFavoriteImport(merge: Bool?) {
        pendingFavoriteImport = nil
        favoriteImportStatus = merge == nil ? "已取消导入" : "正在导入…"
        guard let continuation = importContinuation else { return }
        importContinuation = nil
        continuation.resume(returning: merge)
    }

    @MainActor
    func applyFavoriteImport(rooms: [LiveModel], merge: Bool) async -> Int {
        if !merge {
            for room in favoriteViewModel.roomList {
                try? await favoriteViewModel.removeFavoriteRoom(room: room)
            }
        }
        var imported = 0
        for room in rooms {
            try? await favoriteViewModel.addFavorite(room: room)
            imported += 1
        }
        return imported
    }

    /// 手机网页（/favorites）触发的收藏备份导出/导入。
    private func wireRemoteFavoritesBackup() {
        remoteInputService.favoritesExportProvider = { [weak self] in
            guard let self else { return nil }
            return try? FavoriteBackupService.export(
                rooms: self.favoriteViewModel.roomList,
                format: .angelLive,
                deviceName: currentDeviceName()
            )
        }

        remoteInputService.favoritesImportHandler = { [weak self] data in
            guard let self else { return (false, "未初始化") }
            do {
                let result = try FavoriteBackupService.decode(data)
                guard !result.rooms.isEmpty else {
                    return (false, "备份文件里没有可导入的收藏")
                }
                // 等待电视端选择，浏览器请求保持挂起，避免"显示导入了其实没导入"。
                let choice = await self.requestFavoriteImport(
                    rooms: result.rooms,
                    failures: result.itemFailures.count
                )
                guard let choice else {
                    favoriteImportStatus = "已取消导入"
                    return (false, "已在 Apple TV 上取消导入")
                }
                let count = await self.applyFavoriteImport(rooms: result.rooms, merge: choice)
                let message = choice ? "已合并 \(count) 个收藏" : "已覆盖为 \(count) 个收藏"
                favoriteImportStatus = message
                return (true, message)
            } catch {
                return (false, "导入失败：\(error.localizedDescription)")
            }
        }
    }
}

/// 兼容旧宿主视图层的类型名（移植文件按 `AppState` 引用）。
typealias AppState = TVAppState
