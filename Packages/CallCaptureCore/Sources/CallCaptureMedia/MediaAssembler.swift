#if canImport(AVFoundation)
import AVFoundation
import CoreMedia
import CallCaptureCore

/// Assembles committed segments into an immutable master outside active capture (rule 3).
/// Each source × epoch part (init + segments) is a fragmented MPEG-4 file; parts are placed at
/// their session offsets in one composition and exported by passthrough (no re-encode).
public struct MediaAssembler: RecordingAssembler {
    public init() {}

    public func assemble(recoveryDirectory: URL, manifest: RecoveryManifest, into recordingDirectory: URL) async throws -> FinalizedMedia {
        let files = RecoveryFiles(directory: recoveryDirectory)
        let partsDir = recordingDirectory.appendingPathComponent(".parts", isDirectory: true)
        let fm = FileManager.default
        try fm.createDirectory(at: partsDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: partsDir) }   // regenerable intermediates only

        struct Part { let source: SourceKind; let url: URL; let offset: Double }
        var parts: [Part] = []
        for track in manifest.tracks.sorted(by: { ($0.source, $0.epoch ?? 0) < ($1.source, $1.epoch ?? 0) }) {
            let epoch = track.epoch ?? 0
            let segments = manifest.segments(for: track.source).filter { ($0.epoch ?? 0) == epoch }
            guard !segments.isEmpty else { continue }
            var data = try Data(contentsOf: files.initializationDirectory.appendingPathComponent(track.fileName))
            for seg in segments { data.append(try Data(contentsOf: files.segmentsDirectory.appendingPathComponent(seg.fileName))) }
            let url = partsDir.appendingPathComponent("\(track.source.rawValue)-e\(epoch).mp4")
            try data.write(to: url, options: .atomic)
            parts.append(Part(source: track.source, url: url, offset: segments.map(\.sessionRange.start.seconds).min() ?? 0))
        }
        guard !parts.isEmpty else { throw AssemblyError.noMedia }

        let composition = AVMutableComposition()
        var compositionTracks: [SourceKind: AVMutableCompositionTrack] = [:]
        var order: [SourceKind] = []
        for part in parts {
            let asset = AVURLAsset(url: part.url)
            let mediaType: AVMediaType = part.source == .screen ? .video : .audio
            guard let sourceTrack = try await asset.loadTracks(withMediaType: mediaType).first else { continue }
            let range = try await sourceTrack.load(.timeRange)
            let target: AVMutableCompositionTrack
            if let existing = compositionTracks[part.source] {
                target = existing
            } else {
                guard let t = composition.addMutableTrack(withMediaType: mediaType, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw AssemblyError.compositionFailed
                }
                if mediaType == .video { t.preferredTransform = try await sourceTrack.load(.preferredTransform) }
                compositionTracks[part.source] = t
                order.append(part.source)
                target = t
            }
            try target.insertTimeRange(range, of: sourceTrack, at: CMTime(seconds: part.offset, preferredTimescale: 600))
        }

        let masterName = "master.mov"
        let masterURL = recordingDirectory.appendingPathComponent(masterName)
        if fm.fileExists(atPath: masterURL.path) { try fm.removeItem(at: masterURL) }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw AssemblyError.exportUnavailable
        }
        try await export.export(to: masterURL, as: .mov)
        FileProtectionPolicy.completeUntilFirstUserAuthentication.apply(to: masterURL)

        let validation = try await RecordingValidator.basic(url: masterURL, sources: order)
        let duration = validation.durations.values.max() ?? 0
        let size = (try? fm.attributesOfItem(atPath: masterURL.path)[.size] as? Int) ?? 0
        return FinalizedMedia(masterFileName: masterName, duration: duration, byteCount: size ?? 0, tracks: order, validation: validation)
    }

    public enum AssemblyError: Error { case noMedia, compositionFailed, exportUnavailable }
}

/// RecordingValidator (section 12). BASIC: readable container, tracks, durations and decode
/// windows at start/middle/end. FULL: resumable decode of the whole timeline with hole detection.
public enum RecordingValidator {
    /// Tracks in the master appear in the order the assembler added them; `sources` maps that order.
    public static func basic(url: URL, sources: [SourceKind]) async throws -> ValidationReport {
        let asset = AVURLAsset(url: url)
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        let hash = try? FileHash.sha256(url)
        var notes: [String] = []
        var durations: [String: Double] = [:]
        var result: FileValidation = .basicChecksPassed
        do {
            let tracks = try await asset.load(.tracks)
            if tracks.count != sources.count { notes.append("trackCountMismatch:\(tracks.count)/\(sources.count)") }
            for (index, track) in tracks.enumerated() where index < sources.count {
                let range = try await track.load(.timeRange)
                durations[sources[index].rawValue] = CMTimeRangeGetEnd(range).seconds
                let windows = [range.start.seconds, range.start.seconds + range.duration.seconds / 2,
                               max(range.start.seconds, CMTimeRangeGetEnd(range).seconds - 1)]
                for w in windows {
                    let ok = try decodes(asset: asset, track: track, at: w)
                    if !ok {
                        result = .failed
                        notes.append("decodeFailed:\(sources[index].rawValue)@\(Int(w))")
                    }
                }
            }
            if tracks.isEmpty { result = .failed; notes.append("noTracks") }
        } catch {
            result = .failed
            notes.append("unreadable")
        }
        return ValidationReport(fileName: url.lastPathComponent, byteCount: size ?? 0, sha256: hash, coverage: .basic,
                                result: result, durations: durations, notes: notes)
    }

    private static func decodes(asset: AVAsset, track: AVAssetTrack, at seconds: Double) throws -> Bool {
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = track.mediaType == .video
            ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            : [AVFormatIDKey: kAudioFormatLinearPCM]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { return false }
        reader.add(output)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: max(0, seconds), preferredTimescale: 600),
                                       duration: CMTime(seconds: 1, preferredTimescale: 600))
        guard reader.startReading() else { return false }
        defer { reader.cancelReading() }
        return output.copyNextSampleBuffer() != nil || reader.status == .completed
    }

    /// Resumable full decode in bounded chunks. Call repeatedly until coverage is `.full`.
    public static func full(url: URL, sources: [SourceKind], previous: ValidationReport, chunkSeconds: Double = 120,
                            gapTolerance: Double = 0.25) async throws -> ValidationReport {
        var report = previous
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.load(.tracks)
        var duration = try await asset.load(.duration).seconds
        if !duration.isFinite || duration <= 0 {
            // Fall back to the longest track if the container duration is unavailable.
            var longest = 0.0
            for t in tracks { longest = max(longest, CMTimeRangeGetEnd(try await t.load(.timeRange)).seconds) }
            duration = longest
        }
        let from = report.decodedThrough
        let to = min(duration, from + chunkSeconds)
        guard duration.isFinite, to > from else {
            // Nothing left to decode (or no usable timeline): finish rather than loop forever.
            report.coverage = .full
            if !(duration.isFinite && duration > 0) {
                report.result = .failed
                report.notes.append("noTimeline")
            } else if report.result != .failed {
                report.result = .fullChecksPassed
            }
            return report
        }
        for (index, track) in tracks.enumerated() where index < sources.count {
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: track.mediaType == .video
                ? [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                : [AVFormatIDKey: kAudioFormatLinearPCM])
            output.alwaysCopiesSampleData = false
            reader.add(output)
            reader.timeRange = CMTimeRange(start: CMTime(seconds: from, preferredTimescale: 600),
                                           duration: CMTime(seconds: to - from, preferredTimescale: 600))
            guard reader.startReading() else {
                report.result = .failed
                report.notes.append("readerStartFailed:\(sources[index].rawValue)")
                continue
            }
            var expected = from
            let isAudio = sources[index].isAudio
            while let buffer = output.copyNextSampleBuffer() {
                let r = SampleBufferInspector.range(of: buffer)
                if isAudio && r.start.seconds - expected > gapTolerance {
                    let hole = MediaRange(startSeconds: expected, endSeconds: r.start.seconds)
                    report.detectedRanges.append(hole)
                    report.sourceRanges = report.sourceRanges ?? [:]
                    report.sourceRanges?[sources[index].rawValue, default: []].append(hole)
                }
                expected = max(expected, r.end.seconds)
            }
            if reader.status == .failed {
                report.result = .failed
                report.detectedRanges.append(MediaRange(startSeconds: expected, endSeconds: to))
                report.notes.append("decodeFailed:\(sources[index].rawValue)@\(Int(expected))")
            } else if isAudio && to - expected > gapTolerance && to >= duration - 0.01 {
                // A shorter audio track inside a longer video is a real hole, not a pass (section 6.3).
                let hole = MediaRange(startSeconds: expected, endSeconds: to)
                report.detectedRanges.append(hole)
                report.sourceRanges = report.sourceRanges ?? [:]
                report.sourceRanges?[sources[index].rawValue, default: []].append(hole)
            }
        }
        report.decodedThrough = to
        if to >= duration - 0.01 {
            report.coverage = .full
            if report.result != .failed { report.result = .fullChecksPassed }
        }
        return report
    }
}

enum FileHash {
    static func sha256(_ url: URL) throws -> String {
        #if canImport(CryptoKit)
        return try CryptoFileHash.sha256(url)
        #else
        return try SHA256Hasher.hex(ofFile: url)
        #endif
    }
}
#endif

#if canImport(CryptoKit)
import CryptoKit
import Foundation

enum CryptoFileHash {
    static func sha256(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
#endif
