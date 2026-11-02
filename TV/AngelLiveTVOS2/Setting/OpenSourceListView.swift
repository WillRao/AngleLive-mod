//
//  OpenSourceListView.swift
//  AngelLiveTVOS2
//
//  开源许可列表：资源缺失时给出提示，不做强解包。
//

import SwiftUI
import AngelLiveDependencies

struct OpenSourceListView: View {

    private var acknowList: AcknowList? {
        guard let url = Bundle.main.url(forResource: "Package", withExtension: "resolved"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? AcknowPackageDecoder().decode(from: data)
    }

    var body: some View {
        if let acknowList {
            AcknowListSwiftUIView(acknowList: acknowList)
        } else {
            ContentUnavailableView {
                Label("无法读取开源许可", systemImage: "doc.text")
            } description: {
                Text("安装包内缺少依赖清单文件。")
            }
        }
    }
}
