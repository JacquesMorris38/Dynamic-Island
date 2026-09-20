# Build Mac Island without installing Xcode

You do **not** need Xcode on your Mac for this method.

## GitHub Actions method

1. Create a new **private** GitHub repository.
2. Upload the **contents of this MacIsland folder** to the repository. Make sure `.github/workflows/build-macos.yml` is included.
3. Open the repository's **Actions** tab.
4. Select **Build Mac Island for M5 MacBook Pro**.
5. Click **Run workflow**.
6. When the run completes, download the artifact named **MacIsland-M5-14**.
7. Unzip it and move `MacIsland.app` to `/Applications`.
8. The first time, Control-click the app > **Open** > **Open**. This is expected because this personal build is ad-hoc signed rather than notarized with a paid Apple Developer certificate.
9. Allow Apple Events access if macOS asks for permission to control Music or Spotify.

The workflow builds an Apple-silicon (`arm64`) Release binary, appropriate for the M5 MacBook Pro.

## Why this is needed

SwiftUI and AppKit applications require Apple's macOS SDK to compile. The GitHub macOS runner provides that SDK, so your own Mac does not need Xcode installed.
