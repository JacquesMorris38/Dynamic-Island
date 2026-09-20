# Mac Island

A minimal Dynamic-Island-style utility for notched MacBook displays.

## MVP features

- Notch-aware placement on the built-in MacBook display
- Compact idle state and spring-based hover/click expansion
- Apple Music and Spotify Now Playing controls
- Volume feedback
- Brightness feedback (best effort on the built-in display)
- Battery level and charging feedback
- Launch-at-login registration on macOS 13+
- Accessory app: no Dock icon

## Requirements

- macOS 13 Ventura or newer
- Xcode 15 or newer recommended
- Apple Silicon or Intel Mac

## Run

1. Open `MacIsland.xcodeproj` in Xcode.
2. Select the **MacIsland** scheme and **My Mac**.
3. In **Signing & Capabilities**, choose your Apple Development team if Xcode asks.
4. Press **Run**.
5. The first time Music or Spotify is queried, macOS may ask for permission to control that app. Allow it if you want media controls.

The app is an accessory utility and does not appear in the Dock. Quit it from Xcode while developing, or Activity Monitor after launching it directly.

## Notes

Universal macOS Now Playing metadata is not exposed through a stable public API. This MVP supports Apple Music and Spotify through Apple Events. Browser playback is intentionally excluded.

Brightness is read through the system DisplayServices interface because macOS does not provide a modern public API for built-in display brightness. If Apple changes this interface in a future macOS release, the brightness overlay will simply stop appearing; the rest of the app continues to work.

## Apple-like visual pass

- The compact island now visually merges into the physical notch instead of floating below it.
- Interactive content is laid out beneath the camera cutout, so labels and controls stay visible.
- Compact mode only uses tiny left/right activity indicators to avoid visual clutter.
- Expanded media controls use tighter SF Symbol sizing, rounded typography, and a softer spring transition.
- Volume, brightness, and charging feedback use a single minimal progress treatment.


## 14-inch MacBook Pro (M5, 2025) tuning

This revision is tuned primarily for the 14.2-inch 3024×1964 MacBook Pro display used by the 2025 M5 model. Exact notch dimensions are still read at runtime from `NSScreen.safeAreaInsets` and `auxiliaryTopLeftArea` / `auxiliaryTopRightArea`, so display scaling changes remain supported. The 14-inch hardware profile is used only for tighter visual proportions and fallbacks.
