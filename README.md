# spectrumflutter-native

Native Flutter plugins for the Spectrum apps, and a place to compile them for
free.

## Why this repo exists

Flutter has no Liquid Glass support. The tracking issue
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

iOS 26 Liquid Glass as a Flutter platform view.

```dart
LiquidGlass(
  cornerRadius: 28,
  child: Center(child: Text('on glass')),
)
```

Off iOS the widget is just its child, so callers need no platform branch.
Below iOS 26 it falls back to a plain system blur. Ask
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
  that reason.

## Working on it

No Flutter install needed. The gates run in the same pinned container the app
repos use:

```bash
podman run --rm -v "$PWD":/repo:Z -w /repo/packages/liquid_glass \
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

The iOS build is the part that only CI can run.
