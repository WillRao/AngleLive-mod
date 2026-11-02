//
//  SettingsPageView.swift
//  AngelLiveTVOS2
//
//  设置页：沿用旧版两栏结构（左侧品牌区 + 右侧菜单与子页）。
//  子页分两类：半屏（账号管理 / 通用设置 / 弹幕设置 / 数据同步 / 翻译与字幕）
//  与全屏（插件管理 / 历史记录 / 开源许可 / 关于 / 诊断 / 时间轴 / 收藏备份）。
//

import SwiftUI
import Kingfisher
import AngelLiveCore

struct SettingsPageView: View {
    @Environment(TVAppState.self) private var appState
    @Environment(\.supportDiagnosticsEnabled) private var supportDiagnosticsEnabled

    @ObservedObject private var syncService = PlatformCredentialSyncService.shared

    @State private var selectedIndex: Int?
    @State private var fullScreenItem: FullScreenItem?
    @State private var lastFocusedIndex: Int?
    @FocusState private var focusedIndex: Int?
    @State private var cacheSizeText = "计算中..."
    @State private var isClearingCache = false
    @State private var showClearCacheConfirm = false

    private enum FullScreenItem: Int, Identifiable {
        case pluginManagement
        case history
        case licenses
        case about
        case diagnostics
        case timeline
        case backup

        var id: Int { rawValue }
    }

    private enum SettingsItem: Int, CaseIterable, Identifiable {
        case account
        case plugins
        case general
        case danmaku
        case sync
        case history
        case licenses
        case clearCache
        case about
        case diagnostics
        case translation
        case timeline
        case backup

        var id: Int { rawValue }

        var title: String {
            switch self {
            case .account: return "账号管理"
            case .plugins: return "插件管理"
            case .general: return "通用设置"
            case .danmaku: return "弹幕设置"
            case .sync: return "数据同步"
            case .history: return "历史记录"
            case .licenses: return "开源许可"
            case .clearCache: return "清除缓存"
            case .about: return "关于"
            case .diagnostics: return "问题诊断与反馈"
            case .translation: return "翻译与字幕"
            case .timeline: return "播放时间轴"
            case .backup: return "收藏备份"
            }
        }

        /// 半屏展示的子页（其余走全屏）。
        var isHalfScreen: Bool {
            switch self {
            case .account, .general, .danmaku, .sync, .translation:
                return true
            default:
                return false
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                brandPanel
                    .frame(width: geometry.size.width * 0.36, height: geometry.size.height)

                ZStack {
                    if selectedIndex == nil {
                        menuList
                    } else if let index = selectedIndex,
                              let item = SettingsItem(rawValue: index) {
                        halfScreenContent(item)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .frame(width: geometry.size.width * 0.64 - 50, height: geometry.size.height)
                .padding(.trailing, 50)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedIndex)
        .task { await refreshCacheSize() }
        .fullScreenCover(item: $fullScreenItem) { item in
            fullScreenContent(item)
        }
        .onChange(of: fullScreenItem) { _, newValue in
            guard newValue == nil, let lastFocusedIndex else { return }
            focusedIndex = lastFocusedIndex
        }
        .onChange(of: selectedIndex) { _, newValue in
            guard newValue == nil, let lastFocusedIndex else { return }
            focusedIndex = lastFocusedIndex
        }
        .alert("确认清除所有缓存?", isPresented: $showClearCacheConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                Task { await clearAllCaches() }
            }
        } message: {
            Text("将清理图片缓存、插件旧版本及网络临时文件，不影响收藏与登录状态。")
        }
    }

    // MARK: - 左侧品牌区

    private var brandPanel: some View {
        VStack(spacing: 18) {
            Spacer()
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 260, height: 260)
                .clipShape(RoundedRectangle(cornerRadius: 56, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
            Text("Angel Live")
                .font(.system(size: 34, weight: .semibold))
            Text("Version: \(versionText)")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - 菜单

    /// 菜单展示顺序：常用功能在前，开发者与说明类放最后。
    private var orderedItems: [SettingsItem] {
        [
            .account,
            .plugins,
            .general,
            .danmaku,
            .sync,
            .backup,
            .history,
            .clearCache,
            .translation,
            .timeline,
            .diagnostics,
            .licenses,
            .about
        ]
    }

    private var menuList: some View {
        ScrollView(.vertical) {
            VStack(spacing: 10) {
                ForEach(orderedItems) { item in
                    if shouldShow(item) {
                        Button {
                            open(item)
                        } label: {
                            HStack(spacing: 15) {
                                Text(item.title)
                                    .font(.system(size: 30))
                                    .foregroundStyle(.primary)
                                Spacer()
                                trailingStatus(for: item)
                                if item != .clearCache {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: 56)
                            .padding(.horizontal, 28)
                        }
                        .buttonStyle(.card)
                        .focused($focusedIndex, equals: item.rawValue)
                        .disabled(item == .clearCache && isClearingCache)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func trailingStatus(for item: SettingsItem) -> some View {
        switch item {
        case .account:
            Text(syncService.loggedInByPluginId.values.contains(true) ? "已登录" : "未登录")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
        case .sync:
            Text(appState.favoriteViewModel.syncStatusDisplayText)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
        case .clearCache:
            if isClearingCache {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("清理中…")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(cacheSizeText)
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
            }
        default:
            EmptyView()
        }
    }

    private func shouldShow(_ item: SettingsItem) -> Bool {
        switch item {
        case .account:
            return !appState.pluginAvailability.loginRequiredInstalledPluginIds.isEmpty
        case .diagnostics:
            return supportDiagnosticsEnabled
        case .translation:
            return appState.pluginAvailability.hasAvailablePlugins
        case .timeline:
            return appState.generalSettingsViewModel.developerModeEnabled
        default:
            return true
        }
    }

    private func open(_ item: SettingsItem) {
        switch item {
        case .clearCache:
            showClearCacheConfirm = true
        case .account, .general, .danmaku, .sync, .translation:
            lastFocusedIndex = focusedIndex
            selectedIndex = item.rawValue
        default:
            lastFocusedIndex = focusedIndex
            switch item {
            case .plugins: fullScreenItem = .pluginManagement
            case .history: fullScreenItem = .history
            case .licenses: fullScreenItem = .licenses
            case .about: fullScreenItem = .about
            case .diagnostics: fullScreenItem = .diagnostics
            case .timeline: fullScreenItem = .timeline
            case .backup: fullScreenItem = .backup
            default: break
            }
        }
    }

    // MARK: - 半屏子页

    @ViewBuilder
    private func halfScreenContent(_ item: SettingsItem) -> some View {
        switch item {
        case .account:
            AccountManagementView()
                .environment(appState)
                .onExitCommand { selectedIndex = nil }
        case .general:
            GeneralSettingView()
                .environment(appState)
                .onExitCommand { selectedIndex = nil }
        case .danmaku:
            DanmuSettingMainView()
                .environment(appState)
                .onExitCommand { selectedIndex = nil }
        case .sync:
            SyncManagementView()
                .environment(appState)
                .onExitCommand { selectedIndex = nil }
        case .translation:
            TranslationSettingView()
                .onExitCommand { selectedIndex = nil }
        default:
            EmptyView()
        }
    }

    // MARK: - 全屏子页

    @ViewBuilder
    private func fullScreenContent(_ item: FullScreenItem) -> some View {
        switch item {
        case .pluginManagement:
            PluginManagementView()
                .environment(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onExitCommand { fullScreenItem = nil }
        case .history:
            HistoryListView()
                .environment(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onExitCommand { fullScreenItem = nil }
        case .licenses:
            NavigationStack { OpenSourceListView() }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onExitCommand { fullScreenItem = nil }
        case .about:
            AboutUSView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onExitCommand { fullScreenItem = nil }
        case .diagnostics:
            NavigationStack { SupportDiagnosticsView() }
                .preferredColorScheme(.dark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
        case .timeline:
            NavigationStack {
                PlaybackTimelineView(onClose: { fullScreenItem = nil })
                    .navigationTitle("播放时间轴")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
        case .backup:
            FavoriteBackupView()
                .environment(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .onExitCommand { fullScreenItem = nil }
        }
    }

    // MARK: - 缓存维护

    private func refreshCacheSize() async {
        let total = await CacheMaintenanceService.currentTotalSize(imageCache: Self.kingfisherBridge)
        await MainActor.run {
            guard !isClearingCache else { return }
            cacheSizeText = CacheMaintenanceService.formatBytes(total)
        }
    }

    private func clearAllCaches() async {
        await MainActor.run { isClearingCache = true }
        let total = await CacheMaintenanceService.purgeAllAndAwaitSettled(imageCache: Self.kingfisherBridge)
        await MainActor.run {
            cacheSizeText = CacheMaintenanceService.formatBytes(total)
            isClearingCache = false
        }
    }

    private static let kingfisherBridge = CacheMaintenanceService.ImageCacheBridge(
        measureBytes: {
            await withCheckedContinuation { (cont: CheckedContinuation<Int64, Never>) in
                ImageCache.default.calculateDiskStorageSize { result in
                    cont.resume(returning: (try? result.get()).map(Int64.init) ?? 0)
                }
            }
        },
        clearDisk: {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                ImageCache.default.clearDiskCache { cont.resume() }
            }
        },
        clearMemory: {
            ImageCache.default.clearMemoryCache()
        }
    )

    private var versionText: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short) (\(build))"
    }
}
