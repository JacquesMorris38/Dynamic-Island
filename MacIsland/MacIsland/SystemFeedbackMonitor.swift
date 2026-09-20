import AppKit
import CoreGraphics
import Darwin
import Foundation

final class SystemFeedbackMonitor {
    var onFeedback: ((IslandOverlay) -> Void)?

    private var timer: Timer?
    private var lastVolume: Int?
    private var lastBrightness: Float?
    private let brightness = BrightnessReader()

    func start() {
        sample(initial: true)
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.sample(initial: false)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func sample(initial: Bool) {
        if let volume = readVolume() {
            if !initial, let old = lastVolume, old != volume {
                onFeedback?(IslandOverlay(kind: .volume,
                                          value: Double(volume) / 100.0,
                                          text: "\(volume)%"))
            }
            lastVolume = volume
        }

        if let value = brightness.read() {
            if !initial, let old = lastBrightness, abs(old - value) > 0.008 {
                let percent = Int((value * 100).rounded())
                onFeedback?(IslandOverlay(kind: .brightness,
                                          value: Double(value),
                                          text: "\(percent)%"))
            }
            lastBrightness = value
        }
    }

    private func readVolume() -> Int? {
        guard let raw = AppleScriptRunnerForFeedback.run("output volume of (get volume settings)"),
              let value = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }
        return max(0, min(100, value))
    }
}

private enum AppleScriptRunnerForFeedback {
    static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }
}

private final class BrightnessReader {
    private typealias GetBrightness = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

    private let handle: UnsafeMutableRawPointer?
    private let getter: GetBrightness?

    init() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        handle = dlopen(path, RTLD_LAZY)
        if let handle, let symbol = dlsym(handle, "DisplayServicesGetBrightness") {
            getter = unsafeBitCast(symbol, to: GetBrightness.self)
        } else {
            getter = nil
        }
    }

    deinit {
        if let handle { dlclose(handle) }
    }

    func read() -> Float? {
        guard let getter else { return nil }
        var value: Float = 0
        let result = getter(CGMainDisplayID(), &value)
        guard result == 0, value.isFinite else { return nil }
        return max(0, min(1, value))
    }
}
