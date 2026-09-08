# spectrumflutter-native

Native Flutter plugins for the Spectrum apps, and a place to compile them for
free.

## Why this repo exists

Some of what the Apple platforms offer has no Flutter binding at all. Liquid
Glass is one case; Apple's on-device foundation model is another. The tracking issue
([flutter/flutter#170310](https://github.com/flutter/flutter/issues/170310))
is open and the work is planned for the decoupled `cupertino` package, so the
only way to get Apple's real material today is to put a UIKit
`UIVisualEffectView` on screen yourself.

Writing Swift without a Mac means CI is the compiler. In the private app repos
a macOS runner bills at 10x against a capped Actions budget, which makes
"push and see if it compiles" the most expensive possible way to work. This
repo is public, so GitHub does not bill those minutes, and a Swift typo costs
nothing to find.

**This repo is a compile gate, not a product.** Nothing here ships and nothing
here holds a secret. Visual confirmation happens in the app that consumes the
plugin, on its nightly AltStore build.

## packages/liquid_glass

Apple Liquid Glass as a Flutter platform view: `UIGlassEffect` on iOS 26 and
`NSGlassEffectView` on macOS 26.

```dart
LiquidGlass(
  cornerRadius: 28,
  child: Center(child: Text('on glass')),
)
```

Off iOS and macOS the widget is just its child, so callers need no platform
branch. Below the 26 releases it falls back to a plain system blur. Ask
`liquidGlassSupported()` when you need to hide the feature entirely rather
than degrade it.

### Things worth knowing before using it

- **`UIGlassEffect` ignores `layer.cornerRadius`.** The shape goes through
  iOS 26's `cornerConfiguration`; a glass view left on the default renders
  square no matter what the layer says.
- **A platform view is configured once.** Rebuilding with a new
  `cornerRadius` or `tint` changes nothing. Pass a `Key` that varies with
  those values to force a replacement.
- **Use it for fixed chrome only.** A bar or a floating panel is fine. One
  platform view per row of a scrolling list will drop frames.
- **`interactive: true` makes the native view take touches**, so Flutter
  controls drawn on top of it stop receiving them. It is off by default for
  that reason. On macOS the same flag decides whether `hitTest` claims the
  click.

## packages/apple_ai

Apple's on-device foundation model (Apple Intelligence) as one text-in /
text-out call, on iOS 26 and macOS 26.

```dart
final availability = await appleAiAvailability();
if (availability.isAvailable) {
  final answer = await appleAiRespond(prompt: 'who climbs?');
}
```

The model ships with the OS, so there is no key, no download and no request
budget, and nothing leaves the device. Everywhere else, including Android,
Windows, Linux, the web and older Apple releases, availability answers
`unsupportedOs` without touching the channel. See the package README for the
rest.

## packages/apple_web_auth

`ASWebAuthenticationSession` as an OAuth redirect listener, so a sign-in can
redirect to a registered URL scheme instead of a loopback web server.

```dart
final callback = await appleWebAuthenticate(
  url: authorizeUrl,
  callbackScheme: 'spectrumstrategy',
);
```

A desktop app can bind `127.0.0.1` and have the browser redirect to it
(RFC 8252); an iPhone cannot rely on that. The scheme has to be in the app's
`Info.plist` and match the `redirect_uri` sent to the provider, or the
callback never arrives with no error to read. See the package README.

## Releasing

Tags are repo-wide, not per package: cut one tag, and each app repo pins
whichever package it consumes at that tag. A tag means a release, so a bump
needs the package version, its changelog, the tag and a `gh release create`,
all of it or none.

## Working on it

No Flutter install needed. The gates run in the same pinned container the app
repos use:

```bash
podman run --rm -v "$PWD":/repo:Z -w /repo/packages/<package> \
  ghcr.io/project516/flutter:3.47.2 \
  bash -lc 'export HOME=$(mktemp -d) PUB_CACHE=$HOME/.pub-cache
    git config --global --add safe.directory "*"
    flutter pub get && dart format --output=none --set-exit-if-changed . \
      && flutter analyze --fatal-infos && flutter test'
podman unshare chown -R 0:0 .
```

That last line is not optional. Rootless podman maps the container's uid to a
host subuid, so files the container wrote are unwritable afterwards and an
in-container `chown` does not help.

The iOS and macOS builds are the part that only CI can run.
