import AppKit
import Combine
import CoreGraphics
import QuartzCore
import SwiftUI

final class IslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class IslandWindowController {
    private let model: IslandModel
    private let panel: IslandPanel
    private var cancellables = Set<AnyCancellable>()
    private var screenObserver: NSObjectProtocol?

    init(model: IslandModel) {
        self.model = model
        self.panel = IslandPanel(
            contentRect: NSRect(x: 0, y: 0, width: 226, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        bindModel()
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show() {
        resize(animated: false)
        panel.orderFrontRegardless()
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        panel.contentView = NSHostingView(rootView: IslandView(model: model))

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resize(animated: false)
        }
    }

    private func bindModel() {
        Publishers.CombineLatest3(model.$isExpanded, model.$overlay, model.$trackTitle)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.resize(animated: true)
            }
            .store(in: &cancellables)
    }

    private func resize(animated: Bool) {
        guard let screen = preferredScreen() else { return }

        let measuredNotchWidth = notchWidth(on: screen)
        let measuredNotchDepth = notchDepth(on: screen)

        if abs(model.notchWidth - measuredNotchWidth) > 0.5 {
            model.notchWidth = measuredNotchWidth
        }
        if abs(model.notchDepth - measuredNotchDepth) > 0.5 {
            model.notchDepth = measuredNotchDepth
        }

        let size = targetSize(on: screen)
        let frame = NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.28
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.20, 0.78, 0.30, 1.0)
                context.allowsImplicitAnimation = true
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
        }
    }

    private func targetSize(on screen: NSScreen) -> NSSize {
        let depth = notchDepth(on: screen)
        let fourteenInch = isFourteenInchNotchedMacBook(screen)

        if model.overlay != nil {
            // Slightly tighter on the 14-inch panel so feedback feels attached to the notch.
            return NSSize(width: fourteenInch ? 238 : 248, height: depth + 49)
        }

        if model.isExpanded {
            if model.hasTrack {
                return NSSize(width: fourteenInch ? 304 : 314, height: depth + 61)
            }
            return NSSize(width: fourteenInch ? 252 : 264, height: depth + 59)
        }

        // The compact surface extends only a small distance beyond the real camera
        // housing. On the 14-inch MacBook Pro this gives the "part of the notch" look.
        let wingWidth: CGFloat = fourteenInch ? 46 : 52
        return NSSize(width: notchWidth(on: screen) + wingWidth, height: depth + 5)
    }

    private func preferredScreen() -> NSScreen? {
        if #available(macOS 12.0, *) {
            if let notchScreen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) {
                return notchScreen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    private func notchWidth(on screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *),
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            if gap > 0 { return gap }
        }

        // Fallback tuned for Apple's 14.2-inch 3024x1964 notched panel.
        return isFourteenInchNotchedMacBook(screen) ? 172 : 180
    }

    private func notchDepth(on screen: NSScreen) -> CGFloat {
        if #available(macOS 12.0, *) {
            let top = screen.safeAreaInsets.top
            if top > 0 { return top }
        }

        // The runtime safe-area value is preferred. This fallback is only used if
        // macOS fails to expose the notch geometry.
        return isFourteenInchNotchedMacBook(screen) ? 32 : 30
    }

    /// Apple's 14-inch notched MacBook Pro family, including the 2025 M5 model,
    /// uses a 3024x1964 native panel. We still rely on safeAreaInsets and the
    /// auxiliary top areas for exact geometry; this profile only tunes fallbacks
    /// and visual proportions.
    private func isFourteenInchNotchedMacBook(_ screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return false
        }

        let displayID = CGDirectDisplayID(number.uint32Value)
        let width = CGDisplayPixelsWide(displayID)
        let height = CGDisplayPixelsHigh(displayID)
        let matchesPanel = (width == 3024 && height == 1964) || (width == 1964 && height == 3024)

        if #available(macOS 12.0, *) {
            return matchesPanel && screen.safeAreaInsets.top > 0
        }
        return matchesPanel
    }
}
