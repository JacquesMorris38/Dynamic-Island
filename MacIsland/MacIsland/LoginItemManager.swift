import Foundation
import ServiceManagement

@available(macOS 13.0, *)
private enum LoginItemRegistration {
    static func enable() {
        guard SMAppService.mainApp.status == .notRegistered else { return }
        try? SMAppService.mainApp.register()
    }
}

enum LoginItemManager {
    static func enableIfPossible() {
        if #available(macOS 13.0, *) {
            LoginItemRegistration.enable()
        }
    }
}
