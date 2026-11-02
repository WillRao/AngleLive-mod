//
//  WatchCountStore.swift
//  AngelLiveTVOS2
//
//  本地观看次数统计（收藏排序用）。只记录次数，不上传。
//

import Foundation
import Observation
import AngelLiveCore

@Observable
@MainActor
final class WatchCountStore {
    static let shared = WatchCountStore()

    private static let storageKey = "AngelLiveTVOS2.WatchCounts"

    private(set) var counts: [String: Int] = [:]

    private init() {
        counts = UserDefaults.standard.dictionary(forKey: Self.storageKey) as? [String: Int] ?? [:]
    }

    func record(_ room: LiveModel) {
        let key = Self.key(for: room)
        counts[key] = (counts[key] ?? 0) + 1
        UserDefaults.standard.set(counts, forKey: Self.storageKey)
    }

    func count(for room: LiveModel) -> Int {
        counts[Self.key(for: room)] ?? 0
    }

    private static func key(for room: LiveModel) -> String {
        "\(room.liveType.rawValue)-\(room.roomId)"
    }
}
