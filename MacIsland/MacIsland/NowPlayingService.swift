import Foundation

struct NowPlayingState {
    let source: String
    let title: String
    let artist: String
    let isPlaying: Bool

    static let empty = NowPlayingState(source: "", title: "", artist: "", isPlaying: false)
}

final class NowPlayingService {
    var onUpdate: ((NowPlayingState) -> Void)?

    private var timer: Timer?
    private var lastState = NowPlayingState.empty

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func playPause() { runControl(command: "playpause") }
    func nextTrack() { runControl(command: "next track") }
    func previousTrack() { runControl(command: "previous track") }

    private func poll() {
        let script = #"""
        set outputText to ""
        tell application "System Events"
            set spotifyRunning to exists process "Spotify"
            set musicRunning to exists process "Music"
        end tell

        if spotifyRunning then
            try
                tell application "Spotify"
                    set s to player state as text
                    if s is "playing" or s is "paused" then
                        set t to name of current track
                        set a to artist of current track
                        return "Spotify" & tab & t & tab & a & tab & s
                    end if
                end tell
            end try
        end if

        if musicRunning then
            try
                tell application "Music"
                    set s to player state as text
                    if s is "playing" or s is "paused" then
                        set t to name of current track
                        set a to artist of current track
                        return "Music" & tab & t & tab & a & tab & s
                    end if
                end tell
            end try
        end if

        return ""
        """#

        guard let raw = AppleScriptRunner.run(script), !raw.isEmpty else {
            publish(.empty)
            return
        }

        let parts = raw.components(separatedBy: "\t")
        guard parts.count >= 4 else {
            publish(.empty)
            return
        }

        publish(NowPlayingState(
            source: parts[0],
            title: parts[1],
            artist: parts[2],
            isPlaying: parts[3].lowercased() == "playing"
        ))
    }

    private func publish(_ state: NowPlayingState) {
        let changed = state.source != lastState.source ||
                      state.title != lastState.title ||
                      state.artist != lastState.artist ||
                      state.isPlaying != lastState.isPlaying
        guard changed else { return }
        lastState = state
        onUpdate?(state)
    }

    private func runControl(command: String) {
        guard !lastState.source.isEmpty else { return }
        let app = lastState.source == "Spotify" ? "Spotify" : "Music"
        let script = "tell application \"\(app)\" to \(command)"
        _ = AppleScriptRunner.run(script)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.poll() }
    }
}

private enum AppleScriptRunner {
    static func run(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return result.stringValue
    }
}
