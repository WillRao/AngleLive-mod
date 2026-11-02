//
//  FavoriteBackupView.swift
//  AngelLiveTVOS2
//
//  收藏备份：通过手机浏览器（远程输入服务）导出 / 导入 JSON 备份。
//  手机提交备份后，导入方式（合并 / 覆盖）直接以按钮形式出现在本页，
//  不使用弹窗或覆盖层，避免焦点无法落到选择项。
//

import SwiftUI
import AngelLiveCore

struct FavoriteBackupView: View {
    @Environment(TVAppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let service = appState.remoteInputService
        let url = "http://\(service.localIPAddress):\(service.port)/favorites"

        VStack(spacing: 24) {
            Text("收藏备份")
                .font(.system(size: 36, weight: .bold))

            if let error = service.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.headline)
                Button("重试") {
                    service.stop()
                    service.start()
                }
            } else if service.isRunning && !service.localIPAddress.isEmpty {
                Image(uiImage: Common.generateQRCode(from: url))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 240, height: 240)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.white)
                    )

                Text("用手机扫码打开备份页面")
                    .font(.headline)
                Text(url)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("可导出当前收藏为 JSON，或选择备份文件导入到 Apple TV。")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Text("请确保手机与 Apple TV 在同一局域网；端口 \(service.port)。")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ProgressView()
                Text("正在启动远程服务…")
                    .foregroundStyle(.secondary)
            }

            importSection

            Button("关闭") { dismiss() }
                .padding(.top, 12)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onExitCommand { dismiss() }
    }

    /// 待导入的备份：直接以按钮形式给出导入方式。
    @ViewBuilder
    private var importSection: some View {
        if let pending = appState.pendingFavoriteImport {
            VStack(spacing: 16) {
                Text("收到待导入的收藏（\(pending.rooms.count) 个）")
                    .font(.system(size: 24, weight: .semibold))

                if pending.failures > 0 {
                    Text("\(pending.failures) 个条目因缺少对应平台插件无法导入")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    Button("合并导入") {
                        appState.resolveFavoriteImport(merge: true)
                    }
                    .buttonStyle(.borderedProminent)

                    Button("覆盖导入") {
                        appState.resolveFavoriteImport(merge: false)
                    }
                    .buttonStyle(.bordered)

                    Button("取消") {
                        appState.resolveFavoriteImport(merge: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
        } else if let status = appState.favoriteImportStatus {
            Text(status)
                .font(.system(size: 22))
                .foregroundStyle(.secondary)
        }
    }
}
