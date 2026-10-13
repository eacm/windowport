# WindowPort

**Your Windows apps. One window at a time.**

WindowPort is an open-source iPhone and iPad client plus a small Windows host.
Instead of exposing an entire Windows desktop, the host publishes only the apps
you select. The iOS app presents those apps as a private catalog and opens each
one in a focused touch-friendly session.

## What works in this first milestone

- Add a Windows host by URL and remember it securely in the app's local storage.
- Browse and search only the applications published by that host.
- Pin favorite apps and launch a selected app remotely.
- Open a focused single-app session with pointer, tap, drag, scroll, and keyboard UI.
- Run a Windows companion that exposes health, app catalog, launch, session,
  MJPEG screen stream, and input endpoints.
- Keep the capture/transport behind interfaces so WebRTC can replace the MVP
  MJPEG stream without changing the product model.

This is an early developer build. Use it only on a trusted LAN or over a private
network such as Tailscale. The host intentionally refuses non-private clients by
default and is not ready to expose directly to the public internet.

## Repository layout

```text
WindowPortApp/       SwiftUI iOS/iPadOS application
WindowPortAppTests/  Model and API contract tests
host/WindowPort.Host ASP.NET Core Windows companion
docs/                Architecture and roadmap
```

## Build the iOS app

Requirements: macOS with Xcode 16+, iOS 17+ target, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
brew install xcodegen
xcodegen generate
open WindowPort.xcodeproj
```

The app launches in demo mode, so the catalog and session experience can be
tested without a Windows computer. Add a real host from the Hosts screen.

## Run the Windows host

Requirements: Windows 10/11 and the .NET 8 SDK.

```powershell
cd host\WindowPort.Host
dotnet run --urls http://0.0.0.0:47821
```

Then add `http://YOUR-PC-IP:47821` in WindowPort. Windows Firewall may ask you
to allow private-network access. Published apps live in `published-apps.json`;
the host creates a safe starter file on first launch.

## Security status

The MVP is for trusted private networks. Before a public beta, WindowPort needs
device pairing, mutual authentication, encrypted transport, signed host builds,
per-app authorization, and a permission/audit surface. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Why WindowPort?

The name describes the product literally: a port for an individual window,
not a mirror of an entire desktop. It also leaves room for macOS and visionOS
clients later without tying the identity to one Apple device.

## License

MIT

