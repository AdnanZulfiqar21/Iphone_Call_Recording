import SwiftUI

@main
struct CallCaptureApp: App {
    @State private var model = AppModel()
    @State private var appLock = AppLockService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(model.settings)
                .environment(model.entitlements)
                .environment(appLock)
                .preferredColorScheme(model.settings.appearance.colorScheme)
                .tint(DS.Palette.accent)
                .task { await model.start() }
        }
    }
}
