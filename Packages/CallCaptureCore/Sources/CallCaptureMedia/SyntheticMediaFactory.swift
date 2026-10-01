#if DEBUG && canImport(AVFoundation)
import AVFoundation
import CoreMedia
import CoreVideo
import CallCaptureCore

/// Builds real CMSampleBuffers for synthetic fixtures so the production writer, assembler and
/// validator run on known inputs (SYNTHETIC_TESTED). DEBUG only; never device evidence.
public enum SyntheticMediaFactory {
    public static let sampleRate: Double = 48_000

    /// Payload factory for SyntheticCaptureEngine: tones for audio, solid frames for video.
    public static func payload(for o: SampleObservation) -> (any SamplePayload)? {
        if o.source == .screen {
            guard o.frame == .complete || o.frame == nil else { return nil }
            return videoFrame(pts: o.range.start.seconds, width: 320, height: 640, shade: UInt8(Int(o.range.start.seconds * 20) % 200 + 30))
                .map(SampleBufferPayload.init)
        }
        let silent = o.audio?.isAllZero ?? false
        let frequency = o.source == .microphone ? 440.0 : 660.0
        return audioBuffer(pts: o.range.start.seconds, duration: o.range.duration, frequency: silent ? 0 : frequency,
                           amplitude: silent ? 0 : Float(o.audio?.peak ?? 0.3)).map(SampleBufferPayload.init)
    }

    public static func audioBuffer(pts: Double, duration: Double, frequency: Double, amplitude: Float, channels: Int = 1,
                                   sampleRate: Double = sampleRate) -> CMSampleBuffer? {
        let frames = max(1, Int((duration * sampleRate).rounded()))
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate, mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(4 * channels), mFramesPerPacket: 1, mBytesPerFrame: UInt32(4 * channels),
            mChannelsPerFrame: UInt32(channels), mBitsPerChannel: 32, mReserved: 0)
        var format: CMAudioFormatDescription?
        guard CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                             magicCookie: nil, extensions: nil, formatDescriptionOut: &format) == noErr,
              let format else { return nil }
        let byteCount = frames * 4 * channels
        var block: CMBlockBuffer?
        guard CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: byteCount, blockAllocator: nil,
                                                 customBlockSource: nil, offsetToData: 0, dataLength: byteCount,
                                                 flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block) == noErr,
              let block else { return nil }
        var samples = [Float](repeating: 0, count: frames * channels)
        if frequency > 0 {
            for i in 0..<frames {
                let t = pts + Double(i) / sampleRate
                let v = amplitude * Float(sin(2 * .pi * frequency * t))
                for c in 0..<channels { samples[i * channels + c] = v }
            }
        }
        _ = samples.withUnsafeBytes { CMBlockBufferReplaceDataBytes(with: $0.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: byteCount) }
        var buffer: CMSampleBuffer?
        let start = CMTime(value: CMTimeValue((pts * sampleRate).rounded()), timescale: CMTimeScale(sampleRate))
        guard CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block, formatDescription: format,
                                                                   sampleCount: frames, presentationTimeStamp: start,
                                                                   packetDescriptions: nil, sampleBufferOut: &buffer) == noErr else { return nil }
        return buffer
    }

    public static func videoFrame(pts: Double, width: Int, height: Int, shade: UInt8) -> CMSampleBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]]
        guard CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &pixelBuffer) == kCVReturnSuccess,
              let pixelBuffer else { return nil }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, Int32(shade), CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        var format: CMVideoFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescriptionOut: &format) == noErr,
              let format else { return nil }
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                        presentationTimeStamp: CMTime(seconds: pts, preferredTimescale: 600_000),
                                        decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        guard CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: pixelBuffer, formatDescription: format,
                                                       sampleTiming: &timing, sampleBufferOut: &buffer) == noErr else { return nil }
        return buffer
    }
}
#endif
