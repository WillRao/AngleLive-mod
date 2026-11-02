//
//  PlayerPresentation.swift
//  AngelLiveTVOS2
//
//  播放页呈现数据：持有本次播放的房间 ViewModel。
//

import Foundation
import AngelLiveCore

struct PlayerPresentation: Identifiable {
    let id = UUID()
    let viewModel: RoomInfoViewModel
}
