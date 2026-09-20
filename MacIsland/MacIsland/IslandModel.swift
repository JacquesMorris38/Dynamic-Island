import AppKit
import Combine
import Foundation
import IOKit.ps
import SwiftUI

struct IslandOverlay: Equatable {
    enum Kind {
        case volume
        case brightness
        case charging
    }

    let kind: Kind
    let value: Double
    let text: String

    var symbol: String {
        switch kind {
        case .volume:
            if value <= 0.001 { return "speaker.slash.fill" }
            if value < 0.34 { return "speaker.wave.1.fill" }
            if value < 0.67 { return "speaker.wave.2.fill" }
            return "speaker.wave.3.fill"
        case .brightness:
            return "sun.max.fill"
        case .charging:
            return "bolt.fill"
        }
    }
}

final class IslandModel: ObservableObject {
    @Published var isExpanded = false
    @Published var isPinned = false
    @Published var overlay: IslandOverlay?

    // Updated by the window controller for the active display. These values let
    // SwiftUI keep all visible content out of the physical camera cutout.
    @Published var notchWidth: CGFloat = 180
    @Published var notchDepth: CGFloat = 30

    @Published var trackTitle = ""
    @Published var artist = ""
    @Published var playerSource = ""
    @Published var isPlaying = false

    @Published var batteryLevel = 0
    @Published var isCharging = false

    private let nowPlaying = NowPlayingService()
    private let feedback = SystemFeedbackMonitor()
    private let battery = BatteryMonitor()
    private var overlayDismissWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    var hasTrack: Bool { !trackTitle.isEmpty }

    func start() {
        nowPlaying.onUpdate = { [weak self] state in
            DispatchQueue.main.async {
                self?.trackTitle = state.title
                self?.artist = state.artist
                self?.playerSource = state.source
                self?.isPlaying = state.isPlaying
            }
        }

        feedback.onFeedback = { [weak self] overlay in
            DispatchQueue.main.async {
                self?.present(overlay)
            }
        }

        battery.onUpdate = { [weak self] level, charging, changedChargingState in
            DispatchQueue.main.async {
                guard let self else { return }
                self.batteryLevel = level
                self.isCharging = charging
                if changedChargingState && charging {
                    self.present(IslandOverlay(kind: .charging,
                                               value: Double(level) / 100.0,
                                               text: "\(level)%"))
                }
            }
        }

        nowPlaying.start()
        feedback.start()
        battery.start()
    }

    func stop() {
        nowPlaying.stop()
        feedback.stop()
        battery.stop()
    }

    func hover(_ hovering: Bool) {
        guard !isPinned else { return }
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.08)) {
            isExpanded = hovering
        }
    }

    func togglePinned() {
        isPinned.toggle()
        withAnimation(.spring(response: 0.34, dampingFraction: 0.82, blendDuration: 0.08)) {
            isExpanded = isPinned || isExpanded
        }
    }

    func playPause() { nowPlaying.playPause() }
    func nextTrack() { nowPlaying.nextTrack() }
    func previousTrack() { nowPlaying.previousTrack() }

    private func present(_ value: IslandOverlay) {
        overlayDismissWorkItem?.cancel()
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86, blendDuration: 0.06)) {
            overlay = value
        }

        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.2)) {
                    self?.overlay = nil
                }
            }
        }
        overlayDismissWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }
}
