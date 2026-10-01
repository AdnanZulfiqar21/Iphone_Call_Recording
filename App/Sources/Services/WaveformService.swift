import AVFoundation
import Foundation

/// Waveform peaks from real saved media, computed outside capture and cached with bounded size
/// (section 14.6). Returns nil when the media has no readable audio.
enum WaveformService {
    static let bucketCount = 160

    static func peaks(for url: URL, cache: URL) async -> [Float]? {
        if let data = try? Data(contentsOf: cache), let cached = try? JSONDecoder().decode([Float].self, from: data) {
            return cached
        }
        let result = await Task.detached(priority: .utility) { () -> [Float]? in
            try? await compute(url: url)
        }.value
        if let result, let data = try? JSONEncoder().encode(result) {
            try? FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: cache, options: .atomic)
        }
        return result
    }

    private static func compute(url: URL) async throws -> [Float]? {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        guard duration > 0, let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false, AVNumberOfChannelsKey: 1,
        ])
        reader.add(output)
        guard reader.startReading() else { return nil }
        var buckets = [Float](repeating: 0, count: bucketCount)
        while let buffer = output.copyNextSampleBuffer() {
            let start = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            guard let block = CMSampleBufferGetDataBuffer(buffer) else { continue }
            let length = CMBlockBufferGetDataLength(block)
            var data = [Int16](repeating: 0, count: length / 2)
            _ = data.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
            var rate = 44_100.0
            if let desc = CMSampleBufferGetFormatDescription(buffer),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(desc)?.pointee, asbd.mSampleRate > 0 {
                rate = asbd.mSampleRate
            }
            var i = 0
            while i < data.count {
                let t = start + Double(i) / rate
                let b = min(bucketCount - 1, max(0, Int(t / duration * Double(bucketCount))))
                buckets[b] = max(buckets[b], abs(Float(data[i]) / 32_768))
                i += 64
            }
        }
        let peak = max(buckets.max() ?? 1, 0.05)
        return buckets.map { $0 / peak }
    }
}
