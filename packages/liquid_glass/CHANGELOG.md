## 0.5.0

- `LiquidGlassGroup` draws the glass surfaces under it in one container view
  (`UIGlassContainerEffect` on iOS 26, `NSGlassEffectContainerView` on
  macOS 26), so they share one sampling pass and blend into each other within
  `spacing`. Two separate platform views can never do that.
- A `LiquidGlass` inside a group becomes a shape in that container instead of
  a platform view of its own. Call sites are unchanged.
- Members report their geometry while painting, so a shape that moves or
  resizes follows the widget, animated at an unchanged shape count.

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
