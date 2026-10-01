import Foundation
import LocalAuthentication

/// Optional app lock (section 13). A biometric prompt is not a storage policy: files are
/// protected by the file-protection class regardless of this setting.
@MainActor @Observable
final class AppLockService {
    private(set) var isLocked = false
    private(set) var lastError: String?

    var biometryName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
        switch context.biometryType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default: return String(localized: "Passcode")
        }
    }

    var isAvailable: Bool { LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) }

    func lock() { isLocked = true }

    func unlock() async {
        let context = LAContext()
        context.localizedCancelTitle = String(localized: "Not now")
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                      localizedReason: String(localized: "Unlock your recordings"))
            if ok {
                isLocked = false
                lastError = nil
            }
        } catch {
            lastError = String(localized: "Couldn't unlock. Try again.")
        }
    }
}
