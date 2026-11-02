import Foundation
import CoreMedia
import AngelLiveCore

public class PlayerOptions: KSOptions, @unchecked Sendable {
    public var syncSystemRate: Bool = false

    /// Set per resolved resource by the FullUI session configurator.
    @MainActor public internal(set) var mediaTransform: LiveMediaTransform?

    nonisolated required public init() {
        super.init()
    }

    override public func updateVideo(refreshRate: Float, isDovi: Bool, formatDescription: CMFormatDescription) {
        guard syncSystemRate else { return }
        super.updateVideo(refreshRate: refreshRate, isDovi: isDovi, formatDescription: formatDescription)
    }

    #if canImport(KSPlayer)
    /// 直播的视频帧队列在上游只有个位数容量(isLive 时明显小于点播),码率尖峰或解码
    /// 抖动一旦让视频轨欠载,渲染端就只能按 audio 时钟 `.dropNextFrame` 丢帧,表现
    /// 为持续卡顿。1080p 以内的直播多留几帧解码余量;4K 维持上游值,避免单帧
    /// 12MB 级别的情况下多占上百 MB 内存。
    override public func videoFrameMaxCount(fps: Float, naturalSize: CGSize, isLive: Bool, reorderSize: Int32) -> UInt8 {
        let upstream = super.videoFrameMaxCount(fps: fps, naturalSize: naturalSize, isLive: isLive, reorderSize: reorderSize)
        guard isLive, naturalSize.width <= 1920 else { return upstream }
        return max(upstream, 8)
    }
    #endif
}

#if canImport(KSPlayer)
extension PlayerOptions {
    /// Freeze resource options before background opening. Public per-session values
    /// are copied; transient FFmpeg state, time logs and rendering buffers start fresh.
    @MainActor func mediaTransformSessionSnapshot() -> PlayerOptions {
        let copy = PlayerOptions()
        copy.syncSystemRate = syncSystemRate
        copy.mediaTransform = mediaTransform
        copy.context = context
        copy.avOptions = avOptions
        copy.startPlayTime = startPlayTime
        copy.startPlayTimePercentage = startPlayTimePercentage
        copy.startPlayRate = startPlayRate
        copy.registerRemoteControll = registerRemoteControll
        copy.isAutoPlay = isAutoPlay
        copy.isSecondOpen = isSecondOpen
        copy.playerTypes = playerTypes
        copy.isLoopPlay = isLoopPlay
        copy.loopRange = loopRange
        copy.playbackTimeInterval = playbackTimeInterval
        copy.isAccurateSeek = isAccurateSeek
        copy.isSeekedAutoPlay = isSeekedAutoPlay
        copy.seekFlags = seekFlags
        copy.seekInterruptIO = seekInterruptIO
        copy.outputURL = outputURL
        copy.outputMediaType = outputMediaType
        copy.outputFormatContextOptions = outputFormatContextOptions
        copy.decoderOptions = decoderOptions
        copy.lowres = lowres
        copy.seekUsePacketCache = seekUsePacketCache
        copy.preferredForwardBufferDuration = preferredForwardBufferDuration
        copy.maxBufferDuration = maxBufferDuration
        // 3.x 移除了 per-options 的 audioOutputType:音频输出实现改由静态
        // KSOptions.audioPlayerType 决定,实例上已无此属性可复制。
        copy.audioFilters = audioFilters
        copy.syncDecodeAudio = syncDecodeAudio
        copy.subtitleDisable = subtitleDisable
        copy.subtitleStride = subtitleStride
        copy.audioRecognizes = audioRecognizes
        copy.autoSelectEmbedSubtitle = autoSelectEmbedSubtitle
        copy.isSeekImageSubtitle = isSeekImageSubtitle
        copy.dynamicRange = dynamicRange
        copy.display = display
        copy.videoPipeline = videoPipeline
        copy.vtFramePipeline = vtFramePipeline
        copy.videoDelay = videoDelay
        copy.isRotateByFilter = isRotateByFilter
        copy.destinationDynamicRange = destinationDynamicRange
        copy.videoAdaptable = videoAdaptable
        copy.videoFilters = videoFilters
        copy.syncDecodeVideo = syncDecodeVideo
        copy.videoDecodeType = videoDecodeType
        copy.videoDisable = videoDisable
        copy.canStartPictureInPictureAutomaticallyFromInline = canStartPictureInPictureAutomaticallyFromInline
        copy.automaticWindowResize = automaticWindowResize
        copy.videoSoftDecodeThreadCount = videoSoftDecodeThreadCount
        copy.isDoubleRefreshRate = isDoubleRefreshRate
        copy.renderUseDispatchSourceTimer = renderUseDispatchSourceTimer
        copy.brightness = brightness
        copy.contrast = contrast
        copy.saturation = saturation
        copy.userAgent = userAgent
        // Preserve the exact resolved header/input dictionary after userAgent didSet.
        copy.formatContextOptions = formatContextOptions
        copy.isLive = false
        return copy
    }
}
#endif
