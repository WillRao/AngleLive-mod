//
//  AppGroupIdentifier.swift
//  AngelLiveCore
//
//  App Group 标识符。
//  本地调试签名（个人团队）无法复用正式发布已注册的 App Group，需要唯一名称，
//  因此优先读取 Info.plist 的 `AngelLiveAppGroup`；未配置时回退到正式标识符，
//  保持 iOS / macOS 现有行为不变。
//

import Foundation

public enum AngelLiveAppGroup {
    public static let identifier: String = {
        (Bundle.main.object(forInfoDictionaryKey: "AngelLiveAppGroup") as? String)
            ?? "group.dev.idog.angellivetvos"
    }()
}
