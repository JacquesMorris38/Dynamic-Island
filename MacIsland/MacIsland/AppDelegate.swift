import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = IslandModel()
    private var islandController: IslandWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        islandController = IslandWindowController(model: model)
        islandController?.show()
        model.start()
        LoginItemManager.enableIfPossible()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }
}
