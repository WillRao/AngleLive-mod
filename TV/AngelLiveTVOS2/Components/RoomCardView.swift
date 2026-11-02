//
//  RoomCardView.swift
//  AngelLiveTVOS2
//
//  房间卡片：纯值输入（房间数据 + 是否焦点），不读取页面级状态。
//

import SwiftUI
import AngelLiveCore

struct RoomCardView: View {
    let room: LiveModel
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CoverImage(url: room.roomCover)
                .frame(width: 370, height: 208)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 12) {
                CoverImage(url: room.userHeadImg, pixelSize: CGSize(width: 88, height: 88))
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(room.userName.orDash)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                    Text(room.roomTitle.orDash)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .scaleEffect(isFocused ? 1.05 : 1.0, anchor: .leading)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isFocused)
    }
}
