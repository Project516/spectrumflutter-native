## 0.4.0

- macOS support: `NSGlassEffectView` on macOS 26, an `NSVisualEffectView`
  blur below it, mounted through `AppKitView`. The Swift now lives in a shared
  `darwin/` tree.
- Dropped `dart:io`. Platform detection uses `defaultTargetPlatform`, so the
  web build needs no shim and tests can override it.
- `iosSystemVersion()` is now `systemVersion()` and answers on macOS too.
- On macOS a non-interactive glass view returns nil from `hitTest`, so clicks
  on Flutter controls drawn over it reach Flutter.

## 0.0.1

- Initial `LiquidGlass` platform view over iOS 26's `UIGlassEffect`, with a
  `UIBlurEffect` fallback below iOS 26 and a no-op off iOS.
