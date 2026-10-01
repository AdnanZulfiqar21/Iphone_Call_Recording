import Testing
@testable import CallCaptureMedia

// The AVFoundation pipeline tests run in the iOS simulator app host (AppTests/MediaPipelineTests.swift),
// where a main run loop is available. This target only checks that the module links.
@Test func mediaModuleLoads() {
    #expect(CallCaptureMediaInfo.moduleVersion == 1)
}
