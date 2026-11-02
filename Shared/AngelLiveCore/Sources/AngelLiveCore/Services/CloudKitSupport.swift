//
//  CloudKitSupport.swift
//  AngelLiveCore
//
//  CloudKit 可用性判断。
//
//  侧载/免费签名重签会剥离 iCloud 容器权限。权限缺失时，
//  `CKContainer.default()` 与 `CKContainer(identifier:)` 都会在 CloudKit 内部
//  直接触发 fatalError（EXC_BREAKPOINT，do/catch 无法拦截），因此**不能**用
//  CloudKit API 自身来判断可用性。
//
//  这里改为解析应用内嵌描述文件的 Entitlements（纯文件读取，不触碰 CloudKit）：
//  - 侧载/开发签名：描述文件存在，按其中是否声明容器权限判断；
//  - 无内嵌描述文件（如 App Store 分发）：无法判断，按可用处理，保持原有行为。
//

import Foundation

public enum CloudKitSupport {

    /// 应用使用的 CloudKit 容器（各同步服务共用）。
    public static let containerIdentifier = "iCloud.icloud.dev.igod.simplelive"

    /// 当前进程是否具备 CloudKit 容器权限。进程内只计算一次。
    public static let isAvailable: Bool = {
        let profile = embeddedProfileEntitlements()
        // 无内嵌描述文件（如 App Store 分发）：无法判断，按可用处理，保持原有行为。
        guard profile.exists else { return true }
        // 有描述文件但解析不出 Entitlements：保守按不可用处理，避免 CloudKit trap。
        guard let entitlements = profile.entitlements else { return false }
        let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
        return containers.contains(containerIdentifier)
    }()

    /// 无权限时的统一降级文案。
    public static let unavailableMessage = "当前安装方式未启用 iCloud 同步"

    // MARK: - 内嵌描述文件解析

    private static func embeddedProfileEntitlements() -> (exists: Bool, entitlements: [String: Any]?) {
        let candidates: [(name: String, ext: String)] = [
            ("embedded", "mobileprovision"),
            ("embedded", "provisionprofile")
        ]
        for candidate in candidates {
            guard let url = Bundle.main.url(forResource: candidate.name, withExtension: candidate.ext),
                  let data = try? Data(contentsOf: url) else { continue }
            guard let plist = extractPropertyList(from: data) else {
                return (true, nil)
            }
            return (true, plist["Entitlements"] as? [String: Any])
        }
        return (false, nil)
    }

    /// 描述文件是 CMS 签名包，其中内嵌一段明文 XML plist。
    private static func extractPropertyList(from data: Data) -> [String: Any]? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.upperBound..<data.endIndex) else {
            return nil
        }
        let plistData = Data(data[start.lowerBound..<end.upperBound])
        return (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any]
    }
}
