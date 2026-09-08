import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const MethodChannel _channel = MethodChannel('liquid_glass');
const String _viewType = 'org.spectrum3847.liquid_glass/view';

/// Whether this build runs on an OS the plugin has native code for. Read from
/// `defaultTargetPlatform` rather than `dart:io`, so the web build needs no
/// shim and a test can override it with `debugDefaultTargetPlatformOverride`.
bool get _hasNativeGlass =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Whether the running OS draws a real Liquid Glass surface, meaning iOS 26 or
/// macOS 26 or newer. False everywhere else, including older releases, where
/// [LiquidGlass] still renders but falls back to a plain system blur.
///
/// Gate the feature on this rather than on an OS version parsed in Dart: the
/// answer comes from the same `#available` check the native side compiles
/// against.
Future<bool> liquidGlassSupported() async {
  if (!_hasNativeGlass) return false;
  return await _channel.invokeMethod<bool>('isSupported') ?? false;
}

/// The OS version string, for a debug or settings readout. Null off iOS and
/// macOS.
Future<String?> systemVersion() async {
  if (!_hasNativeGlass) return null;
  return _channel.invokeMethod<String>('systemVersion');
}

/// A Liquid Glass surface, with [child] drawn on top of it.
///
/// Off iOS and macOS this is just [child], so a caller needs no platform
/// branch of its own.
///
/// Two constraints come from this being a native platform view rather than
/// something Flutter paints:
///
/// * It is configured once, at creation. Rebuilding with a different
///   [cornerRadius] or [tint] changes nothing. Pass a [Key] that varies with
///   those values when they need to change, so the element is replaced.
/// * It is expensive relative to a painted box. Use it for fixed chrome such
///   as a bar, a menu, or a floating panel, never inside a scrolling list,
///   where one platform view per row will drop frames.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    this.cornerRadius = 0,
    this.interactive = false,
    this.tint,
    this.child,
  });

  /// Corner radius in logical pixels.
  final double cornerRadius;

  /// Whether the glass reacts to touch with a specular highlight.
  ///
  /// This also makes the native view take touches, so anything interactive in
  /// [child] stops receiving them. Leave it false for chrome that sits under
  /// buttons.
  final bool interactive;

  /// An optional tint mixed into the glass. Keep it near-transparent; an
  /// opaque tint defeats the material.
  final Color? tint;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (!_hasNativeGlass) return child ?? const SizedBox.shrink();

    final params = <String, Object?>{
      'cornerRadius': cornerRadius,
      'interactive': interactive,
      'tintArgb': tint?.toARGB32(),
    };
    final Widget glass = defaultTargetPlatform == TargetPlatform.macOS
        ? AppKitView(
            viewType: _viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
          )
        : UiKitView(
            viewType: _viewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
          );

    if (child == null) return glass;
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        Positioned.fill(child: glass),
        child!,
      ],
    );
  }
}
