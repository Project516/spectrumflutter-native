import 'package:flutter/foundation.dart';

/// The platform view type of a single glass surface.
const String glassViewType = 'org.spectrum3847.liquid_glass/view';

/// The platform view type of a glass group container.
const String glassGroupViewType = 'org.spectrum3847.liquid_glass/group';

/// Whether this build runs on an OS the plugin has native code for. Read from
/// `defaultTargetPlatform` rather than `dart:io`, so the web build needs no
/// shim and a test can override it with `debugDefaultTargetPlatformOverride`.
bool get hasNativeGlass =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);
