import AppKit
import SwiftUI

/// A notch-attached surface: the top edge is intentionally square so it visually
/// merges into the physical camera housing; only the visible lower edge is rounded.
private struct NotchIslandShape: Shape {
    var bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let radius = min(bottomRadius, min(rect.width, rect.height) / 2)
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control1: CGPoint(x: rect.maxX, y: rect.maxY - radius * 0.42),
            control2: CGPoint(x: rect.maxX - radius * 0.42, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control1: CGPoint(x: rect.minX + radius * 0.42, y: rect.maxY),
            control2: CGPoint(x: rect.minX, y: rect.maxY - radius * 0.42)
        )
        path.closeSubpath()
        return path
    }
}

struct IslandView: View {
    @ObservedObject var model: IslandModel

    private var surfaceRadius: CGFloat {
        if model.overlay != nil { return 18 }
        return model.isExpanded ? 22 : 9
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchIslandShape(bottomRadius: surfaceRadius)
                .fill(.black)

            content
        }
        .contentShape(Rectangle())
        .onHover { model.hover($0) }
        .onTapGesture {
            if model.overlay == nil {
                model.togglePinned()
            }
        }
        .contextMenu {
            Button("Quit Mac Island") {
                NSApp.terminate(nil)
            }
        }
        .animation(.spring(response: 0.31, dampingFraction: 0.83, blendDuration: 0.05), value: model.isExpanded)
        .animation(.spring(response: 0.27, dampingFraction: 0.88, blendDuration: 0.04), value: model.overlay)
    }

    @ViewBuilder
    private var content: some View {
        if let overlay = model.overlay {
            overlayView(overlay)
                .padding(.top, model.notchDepth + 8)
                .padding(.horizontal, 15)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        } else if model.isExpanded {
            expandedView
                .padding(.top, model.notchDepth + 10)
                .padding(.horizontal, 15)
                .padding(.bottom, 13)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
        } else {
            compactView
                .transition(.opacity)
        }
    }

    /// Compact mode intentionally keeps the physical camera area empty. Small
    /// indicators live only in the visible wings to either side of the notch.
    private var compactView: some View {
        HStack(spacing: 0) {
            ZStack {
                if model.hasTrack {
                    Image(systemName: model.isPlaying ? "waveform" : "pause.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(model.isPlaying ? 0.95 : 0.58))
                }
            }
            .frame(width: 20, height: model.notchDepth)

            Spacer(minLength: model.notchWidth + 5)

            ZStack {
                if model.isCharging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 8.8, weight: .bold))
                        .foregroundStyle(.green)
                }
            }
            .frame(width: 20, height: model.notchDepth)
        }
        .padding(.horizontal, 5)
        .frame(height: model.notchDepth, alignment: .top)
    }

    private var expandedView: some View {
        HStack(spacing: 12) {
            leadingGlyph

            VStack(alignment: .leading, spacing: 2.5) {
                Text(primaryText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(secondaryText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if model.hasTrack {
                HStack(spacing: 3) {
                    mediaButton("backward.fill", action: model.previousTrack)
                    mediaButton(model.isPlaying ? "pause.fill" : "play.fill", prominent: true, action: model.playPause)
                    mediaButton("forward.fill", action: model.nextTrack)
                }
            } else {
                batteryStatus
            }
        }
    }

    private var leadingGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(0.09))

            Image(systemName: model.hasTrack ? "music.note" : batterySymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(model.hasTrack ? .white : (model.isCharging ? .green : .white.opacity(0.9)))
        }
        .frame(width: 36, height: 36)
    }

    private func overlayView(_ overlay: IslandOverlay) -> some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.09))

                Image(systemName: overlay.symbol)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(overlay.kind == .charging ? .green : .white)
            }
            .frame(width: 29, height: 29)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(height: 4)

                    Capsule()
                        .fill(overlay.kind == .charging ? Color.green : Color.white)
                        .frame(width: max(4, proxy.size.width * max(0, min(1, overlay.value))), height: 4)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 14)

            Text(overlay.text)
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.66))
                .frame(width: 34, alignment: .trailing)
        }
    }

    private var primaryText: String {
        model.hasTrack ? model.trackTitle : (model.isCharging ? "Charging" : "MacBook Pro")
    }

    private var secondaryText: String {
        if model.hasTrack {
            if !model.artist.isEmpty { return model.artist }
            if !model.playerSource.isEmpty { return model.playerSource }
            return model.isPlaying ? "Playing" : "Paused"
        }
        return model.isCharging ? "Battery · \(model.batteryLevel)%" : "Battery · \(model.batteryLevel)%"
    }

    private var batteryStatus: some View {
        HStack(spacing: 5) {
            Image(systemName: model.isCharging ? "bolt.fill" : batterySymbol)
                .font(.system(size: 10.5, weight: .semibold))
            Text("\(model.batteryLevel)%")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(model.isCharging ? .green : .white.opacity(0.58))
    }

    private var batterySymbol: String {
        switch model.batteryLevel {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        case 1...25: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    private func mediaButton(_ symbol: String, prominent: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: prominent ? 11.5 : 10, weight: .semibold))
                .foregroundStyle(.white.opacity(prominent ? 0.98 : 0.72))
                .frame(width: prominent ? 29 : 24, height: prominent ? 29 : 24)
                .background(prominent ? Color.white.opacity(0.11) : Color.clear)
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
