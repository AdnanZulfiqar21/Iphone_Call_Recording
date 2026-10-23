import Foundation
import Photos

/// Adds a copy of a recording to Photos (add-only access: CallCapture can't read the library).
/// The master stays in CallCapture (rule 19). Used by the result screen, the player and Export.
enum PhotoLibrarySaver {
    enum Outcome: Equatable {
        case saved
        case denied
        case failed
    }

    static func saveVideo(at url: URL) async -> Outcome {
        let auth = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard auth == .authorized || auth == .limited else { return .denied }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false   // copy: the master stays in CallCapture
                request.addResource(with: .video, fileURL: url, options: options)
            }
            return .saved
        } catch {
            return .failed
        }
    }

    static func message(for outcome: Outcome) -> String {
        switch outcome {
        case .saved: String(localized: "Saved to Photos")
        case .denied: String(localized: "Photos access wasn't allowed. You can change this in Settings.")
        case .failed: String(localized: "Couldn't save to Photos. The original is unchanged.")
        }
    }
}
