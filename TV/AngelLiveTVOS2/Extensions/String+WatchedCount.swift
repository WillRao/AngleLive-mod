//
//  String+WatchedCount.swift
//  AngelLiveTVOS2
//
//  观看人数格式化（移植自旧宿主；避免复制与 Core 重名的扩展）。
//

import Foundation

extension String {
    func formatWatchedCount() -> String {
        guard allSatisfy({ $0.isNumber }) else { return self }
        let count = Double(self) ?? 0
        guard count > 10000 else { return self }
        return String(format: "%.1f万", count / 10000)
    }
}
