//
//  CoverImage.swift
//  AngelLiveTVOS2
//
//  统一封面管线：按显示尺寸降采样解码 + 内存缓存 + 淡入。
//  所有卡片/头像/大图必须走这里，避免散落的全尺寸解码。
//

import SwiftUI
import Kingfisher
import AngelLiveDependencies

struct CoverImage: View {
    let url: String
    var pixelSize: CGSize = CGSize(width: 740, height: 420)

    var body: some View {
        KFImage(URL(string: url))
            .placeholder {
                Rectangle().fill(.white.opacity(0.06))
            }
            .setProcessor(DownsamplingImageProcessor(size: pixelSize))
            .fade(duration: 0.2)
            .cacheMemoryOnly()
            .resizable()
            .scaledToFill()
    }
}
