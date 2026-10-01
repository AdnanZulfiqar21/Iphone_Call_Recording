#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import CallCaptureCore

/// Carries a CMSampleBuffer through the core pipeline. CMSampleBuffer is immutable once
/// created by the capture framework, so sharing it across the writer queue is safe.
public struct SampleBufferPayload: SamplePayload, @unchecked Sendable {
    public let buffer: CMSampleBuffer
    public init(_ buffer: CMSampleBuffer) { self.buffer = buffer }
}

public extension MediaTime {
    init(_ time: CMTime) {
        if time.isValid && time.isNumeric && !time.isIndefinite && time.timescale > 0 {
            self.init(value: time.value, timescale: time.timescale)
        } else {
            self = .invalid
        }
    }

    var cmTime: CMTime { CMTime(value: value, timescale: timescale) }
}

public enum SampleBufferInspector {
    /// Presentation range of a buffer. Falls back to 1/30 s for video frames without a duration.
    public static func range(of buffer: CMSampleBuffer, fallbackDuration: Double = 1.0 / 30) -> MediaRange {
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        var duration = CMSampleBufferGetDuration(buffer)
        if !duration.isValid || !duration.isNumeric || duration.seconds <= 0 {
            let samples = CMSampleBufferGetNumSamples(buffer)
            if let asbd = audioFormat(of: buffer), asbd.mSampleRate > 0, samples > 0 {
                duration = CMTime(value: CMTimeValue(samples), timescale: CMTimeScale(asbd.mSampleRate))
            } else {
                duration = CMTime(seconds: fallbackDuration, preferredTimescale: 600)
            }
        }
        let start = MediaTime(pts)
        guard start.isValid else { return MediaRange(start: .invalid, end: .invalid) }
        return MediaRange(start: start, end: MediaTime(seconds: start.seconds + duration.seconds))
    }

    public static func audioFormat(of buffer: CMSampleBuffer) -> AudioStreamBasicDescription? {
        guard let desc = CMSampleBufferGetFormatDescription(buffer),
              let p = CMAudioFormatDescriptionGetStreamBasicDescription(desc) else { return nil }
        return p.pointee
    }

    public static func byteCount(of buffer: CMSampleBuffer) -> Int {
        if let image = CMSampleBufferGetImageBuffer(buffer) {
            return CVPixelBufferGetDataSize(image)
        }
        return CMSampleBufferGetTotalSampleSize(buffer)
    }

    /// Identity of a stream format, used to detect route/format epochs.
    public static func formatKey(of buffer: CMSampleBuffer) -> String {
        if let asbd = audioFormat(of: buffer) {
            return "a:\(asbd.mSampleRate):\(asbd.mChannelsPerFrame):\(asbd.mFormatID):\(asbd.mFormatFlags):\(asbd.mBitsPerChannel)"
        }
        if let image = CMSampleBufferGetImageBuffer(buffer) {
            return "v:\(CVPixelBufferGetWidth(image))x\(CVPixelBufferGetHeight(image)):\(CVPixelBufferGetPixelFormatType(image))"
        }
        return "unknown"
    }
}

/// Bounded, downsampled measurements from actual audio samples (section 14.7).
public enum AudioAnalyzer {
    public static func summarize(_ buffer: CMSampleBuffer) -> AudioContentSummary? {
        guard let asbd = SampleBufferInspector.audioFormat(of: buffer), asbd.mFormatID == kAudioFormatLinearPCM else { return nil }
        var blockBuffer: CMBlockBuffer?
        var listSize = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(buffer, bufferListSizeNeededOut: &listSize, bufferListOut: nil,
                                                                bufferListSize: 0, blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
                                                                flags: 0, blockBufferOut: nil)
        guard listSize > 0 else { return nil }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: listSize, alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            buffer, bufferListSizeNeededOut: nil, bufferListOut: list, bufferListSize: listSize,
            blockBufferAllocator: nil, blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment, blockBufferOut: &blockBuffer)
        guard status == noErr else { return nil }

        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let bits = Int(asbd.mBitsPerChannel)
        var peak: Float = 0
        var sumSquares: Double = 0
        var count = 0
        var clipped = 0
        var allZero = true
        // Stride keeps the analysis cheap on the capture path (bounded work per buffer).
        let stride = 4
        for audioBuffer in UnsafeMutableAudioBufferListPointer(list) {
            guard let data = audioBuffer.mData else { continue }
            let bytes = Int(audioBuffer.mDataByteSize)
            if isFloat && bits == 32 {
                let n = bytes / 4
                let p = data.bindMemory(to: Float.self, capacity: n)
                var i = 0
                while i < n {
                    let v = abs(p[i])
                    if v != 0 { allZero = false }
                    peak = max(peak, v)
                    sumSquares += Double(v * v)
                    if v >= 0.999 { clipped += 1 }
                    count += 1
                    i += stride
                }
            } else if !isFloat && bits == 16 {
                let n = bytes / 2
                let p = data.bindMemory(to: Int16.self, capacity: n)
                var i = 0
                while i < n {
                    let v = abs(Float(p[i]) / 32_768)
                    if p[i] != 0 { allZero = false }
                    peak = max(peak, v)
                    sumSquares += Double(v * v)
                    if v >= 0.999 { clipped += 1 }
                    count += 1
                    i += stride
                }
            } else if !isFloat && bits == 32 {
                let n = bytes / 4
                let p = data.bindMemory(to: Int32.self, capacity: n)
                var i = 0
                while i < n {
                    let v = abs(Float(p[i]) / 2_147_483_648)
                    if p[i] != 0 { allZero = false }
                    peak = max(peak, v)
                    sumSquares += Double(v * v)
                    if v >= 0.999 { clipped += 1 }
                    count += 1
                    i += stride
                }
            } else {
                return nil
            }
        }
        guard count > 0 else { return nil }
        return AudioContentSummary(peak: min(1, peak), rms: Float((sumSquares / Double(count)).squareRoot()),
                                   isAllZero: allZero, clippedFraction: Float(clipped) / Float(count))
    }
}
#endif
