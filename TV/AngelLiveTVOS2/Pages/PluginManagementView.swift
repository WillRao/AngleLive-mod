//
//  PluginManagementView.swift
//  AngelLiveTVOS2
//
//  插件管理：订阅源、可用插件、安装/更新与确认。
//

import SwiftUI
import AngelLiveCore

struct PluginManagementView: View {
    @Environment(TVAppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isAddingSource = false
    @State private var sourceInput = ""
    @State private var isInstallingAll = false
    @State private var loginPluginId: String?

    var body: some View {
        List {
            Section("订阅源") {
                ForEach(appState.pluginSourceManager.sourceURLs, id: \.self) { url in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url)
                                .font(.system(size: 18))
                                .lineLimit(1)
                            Text(healthText(url))
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if appState.pluginSourceManager.health(for: url).isFailed {
                            Button("重试") {
                                Task {
                                    _ = await appState.pluginSourceManager.refreshSource(url)
                                    await appState.pluginAvailability.refresh()
                                }
                            }
                        }
                        Button("移除") {
                            Task {
                                await appState.pluginSourceManager.removeSourceAndAssociatedPlugins(url)
                                await appState.pluginAvailability.refresh()
                            }
                        }
                    }
                }

                Button("添加订阅源") { isAddingSource = true }

                Button(isInstallingAll ? "正在安装…" : "安装全部插件") {
                    Task { await installAll() }
                }
                .disabled(isInstallingAll || appState.pluginSourceManager.remotePlugins.isEmpty)
            }

            if let errorMessage = appState.pluginSourceManager.errorMessage, !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            if !loginRequiredPluginIds.isEmpty {
                Section("需要登录的平台") {
                    ForEach(loginRequiredPluginIds, id: \.self) { pluginId in
                        HStack {
                            Text(displayName(for: pluginId))
                            Spacer()
                            Button("去登录") { loginPluginId = pluginId }
                        }
                    }
                }
            }

            Section("可用插件") {
                if appState.pluginSourceManager.remotePlugins.isEmpty {
                    Text("添加订阅源后，这里会列出可安装的插件")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(appState.pluginSourceManager.remotePlugins) { item in
                        pluginRow(item)
                    }
                }
            }
        }
        .task {
            await appState.pluginSourceManager.fetchAllSourceIndexes()
        }
        .fullScreenCover(isPresented: $isAddingSource) {
            addSourceSheet
        }
        .alert(
            appState.consentService.alertTitle,
            isPresented: Binding(
                get: { appState.consentService.isPresenting },
                set: { if !$0 { appState.consentService.resolve(false) } }
            )
        ) {
            Button("继续") { appState.consentService.resolve(true) }
            Button("取消", role: .cancel) { appState.consentService.resolve(false) }
        } message: {
            Text(appState.consentService.alertMessage)
        }
        .onExitCommand { dismiss() }
        .fullScreenCover(item: $loginPluginId) { pluginId in
            AccountManagementView(recoveryPluginIDs: [pluginId])
                .environment(appState)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
        }
    }

    private var loginRequiredPluginIds: [String] {
        Array(appState.pluginAvailability.loginRequiredInstalledPluginIds).sorted()
    }

    private func displayName(for pluginId: String) -> String {
        if let platform = LiveParseJSPlatformManager.platform(forPluginId: pluginId) {
            if let name = platform.platformName, !name.isEmpty {
                return name
            }
            if let liveType = platform.liveTypes.first {
                return LiveParseTools.getLivePlatformName(liveType)
            }
        }
        return pluginId
    }

    private func pluginRow(_ item: RemotePluginDisplayItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName)
                Text("版本 \(item.item.version)")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            actionView(for: item)
        }
    }

    @ViewBuilder
    private func actionView(for item: RemotePluginDisplayItem) -> some View {
        switch appState.pluginSourceManager.catalogActionState(for: item) {
        case .install:
            Button("安装") {
                Task {
                    _ = await appState.pluginSourceManager.installPlugin(item)
                    await appState.pluginAvailability.refresh()
                }
            }
        case .update:
            Button("更新") {
                Task {
                    _ = await appState.pluginSourceManager.updatePlugin(pluginId: item.item.pluginId)
                    await appState.pluginAvailability.refresh()
                }
            }
        case .installed:
            HStack(spacing: 16) {
                Text("已安装")
                    .foregroundStyle(.secondary)
                Button("卸载") {
                    _ = appState.pluginSourceManager.uninstallPlugin(pluginId: item.item.pluginId)
                    Task { await appState.pluginAvailability.refresh() }
                }
            }
        case .installing, .updating:
            ProgressView()
        case .failed(let message):
            VStack(alignment: .trailing, spacing: 4) {
                Button("重试") {
                    Task {
                        _ = await appState.pluginSourceManager.installPlugin(item)
                        await appState.pluginAvailability.refresh()
                    }
                }
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private func installAll() async {
        guard !isInstallingAll else { return }
        isInstallingAll = true
        _ = await appState.pluginSourceManager.installAll()
        await appState.pluginAvailability.refresh()
        isInstallingAll = false
    }

    private func healthText(_ url: String) -> String {
        switch appState.pluginSourceManager.health(for: url) {
        case .unknown:
            return "尚未拉取"
        case .checking:
            return "正在拉取索引…"
        case .healthy(let count):
            return "可用，共 \(count) 个插件"
        case .failed(let reason):
            return "拉取失败：\(reason)"
        }
    }

    private var addSourceSheet: some View {
        VStack(spacing: 30) {
            Text("添加订阅源")
                .font(.title2)
            TextField("输入订阅源地址或口令", text: $sourceInput)
                .textFieldStyle(.plain)
                .frame(maxWidth: 900)
            HStack(spacing: 30) {
                Button("取消") { isAddingSource = false }
                Button("添加") {
                    let input = sourceInput
                    sourceInput = ""
                    isAddingSource = false
                    Task {
                        _ = await appState.pluginSourceManager.addSourceFromInput(input)
                        await appState.pluginSourceManager.fetchAllSourceIndexes()
                        await appState.pluginAvailability.refresh()
                    }
                }
                .disabled(sourceInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(80)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}
