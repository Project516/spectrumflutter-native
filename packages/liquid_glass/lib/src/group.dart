import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'platform.dart';

/// One glass shape's geometry and appearance, in the coordinate space of the
/// group that owns it.
@immutable
class GlassShape {
  const GlassShape({
    required this.rect,
    required this.cornerRadius,
    required this.tintArgb,
    required this.interactive,
  });

  final Rect rect;
  final double cornerRadius;
  final int? tintArgb;
  final bool interactive;

  Map<String, Object?> toParams() => <String, Object?>{
    'x': rect.left,
    'y': rect.top,
    'width': rect.width,
    'height': rect.height,
    'cornerRadius': cornerRadius,
    'tintArgb': tintArgb,
    'interactive': interactive,
  };

  @override
  bool operator ==(Object other) =>
      other is GlassShape &&
      other.rect == rect &&
      other.cornerRadius == cornerRadius &&
      other.tintArgb == tintArgb &&
      other.interactive == interactive;

  @override
  int get hashCode => Object.hash(rect, cornerRadius, tintArgb, interactive);
}

/// Collects the members of one group and pushes them to the native container.
///
/// Members report their geometry while painting, which is the first moment
/// their rect relative to the group is known. Sends are coalesced to one per
/// frame: a member that repaints without moving costs nothing.
class GlassGroupRegistry {
  GlassGroupRegistry(this._resolveGroupBox);

  final RenderBox? Function() _resolveGroupBox;

  /// The render box every member measures itself against. Null until the
  /// group's own element is mounted.
  RenderBox? get groupBox => _resolveGroupBox();

  final List<Object> _order = <Object>[];
  final Map<Object, GlassShape> _shapes = <Object, GlassShape>{};

  MethodChannel? _channel;
  bool _flushScheduled = false;
  bool _dirty = false;
  double _spacing = 0;

  /// How close two shapes come before they merge, in logical pixels.
  double get spacing => _spacing;
  set spacing(double value) {
    if (value == _spacing) return;
    _spacing = value;
    _markDirty();
  }

  /// Binds the registry to the container platform view once it exists. Shapes
  /// registered before that are flushed here.
  void attach(int viewId) {
    _channel = MethodChannel('liquid_glass/group_$viewId');
    _markDirty();
  }

  void put(Object id, GlassShape shape) {
    if (_shapes[id] == shape) return;
    if (!_shapes.containsKey(id)) _order.add(id);
    _shapes[id] = shape;
    _markDirty();
  }

  void remove(Object id) {
    if (_shapes.remove(id) == null) return;
    _order.remove(id);
    _markDirty();
  }

  void _markDirty() {
    _dirty = true;
    if (_flushScheduled) return;
    _flushScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _flushScheduled = false;
      _flush();
    });
  }

  void _flush() {
    final MethodChannel? channel = _channel;
    if (channel == null || !_dirty) return;
    _dirty = false;
    channel.invokeMethod<void>('setShapes', <String, Object?>{
      'spacing': _spacing,
      'shapes': <Map<String, Object?>>[
        for (final Object id in _order) _shapes[id]!.toParams(),
      ],
    });
  }
}

/// Hands the enclosing group's registry to the [LiquidGlass] widgets under it.
class GlassGroupScope extends InheritedWidget {
  const GlassGroupScope({
    required this.registry,
    required super.child,
    super.key,
  });

  final GlassGroupRegistry registry;

  static GlassGroupRegistry? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassGroupScope>()?.registry;

  @override
  bool updateShouldNotify(GlassGroupScope oldWidget) =>
      oldWidget.registry != registry;
}

/// Groups the [LiquidGlass] surfaces beneath it into one native container, so
/// they share a single sampling pass and merge into each other when they come
/// within [spacing].
///
/// This is Apple's `UIGlassContainerEffect` / `NSGlassEffectContainerView`.
/// Two separate glass views each sample the backdrop on their own and stay
/// two hard-edged shapes however close they get; two shapes in one container
/// blend at the edges as they approach, the way the system tab bar and its
/// accessory do.
///
/// Off iOS and macOS this is just [child], and on those platforms below the
/// 26 releases it is a plain blur per shape with no merging, so a caller needs
/// no platform branch of its own.
///
/// **Paint order is the thing to get right.** The container is one native
/// layer, painted where this widget sits, with [child] on top of it. Glass
/// samples what is painted *below* that layer, so put the group above the
/// content it should refract and keep the labels drawn on the glass inside
/// [child]:
///
/// ```dart
/// Stack(
///   children: <Widget>[
///     body,
///     LiquidGlassGroup(
///       spacing: 40,
///       child: Stack(children: <Widget>[appBar, tabBar]),
///     ),
///   ],
/// )
/// ```
///
/// A member that stays in the tree but stops painting (`Offstage`,
/// `Visibility(visible: false)`) keeps its shape in the container, because the
/// report happens while painting. Build the member conditionally instead.
class LiquidGlassGroup extends StatefulWidget {
  const LiquidGlassGroup({super.key, this.spacing = 0, required this.child});

  /// How close two member shapes come before they merge, in logical pixels.
  /// Zero means they merge only when they touch.
  final double spacing;

  final Widget child;

  @override
  State<LiquidGlassGroup> createState() => _LiquidGlassGroupState();
}

class _LiquidGlassGroupState extends State<LiquidGlassGroup> {
  final GlobalKey _boundsKey = GlobalKey();
  late final GlassGroupRegistry _registry = GlassGroupRegistry(_resolveBounds)
    ..spacing = widget.spacing;

  RenderBox? _resolveBounds() =>
      _boundsKey.currentContext?.findRenderObject() as RenderBox?;

  @override
  void didUpdateWidget(LiquidGlassGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registry.spacing = widget.spacing;
  }

  @override
  Widget build(BuildContext context) {
    if (!hasNativeGlass) return widget.child;

    final Map<String, Object?> params = <String, Object?>{
      'spacing': widget.spacing,
    };
    final Widget container = defaultTargetPlatform == TargetPlatform.macOS
        ? AppKitView(
            viewType: glassGroupViewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _registry.attach,
          )
        : UiKitView(
            viewType: glassGroupViewType,
            creationParams: params,
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _registry.attach,
          );

    return GlassGroupScope(
      registry: _registry,
      child: Stack(
        key: _boundsKey,
        fit: StackFit.passthrough,
        children: <Widget>[
          Positioned.fill(child: container),
          widget.child,
        ],
      ),
    );
  }
}

/// A single shape inside a group. Draws nothing itself: it reports where it
/// is, and the group's container view draws the glass there.
class GlassGroupMember extends SingleChildRenderObjectWidget {
  const GlassGroupMember({
    required this.registry,
    required this.cornerRadius,
    required this.interactive,
    required this.tintArgb,
    super.key,
    super.child,
  });

  final GlassGroupRegistry registry;
  final double cornerRadius;
  final bool interactive;
  final int? tintArgb;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderGlassMember(registry, cornerRadius, interactive, tintArgb);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderGlassMember renderObject,
  ) {
    renderObject
      ..registry = registry
      ..cornerRadius = cornerRadius
      ..interactive = interactive
      ..tintArgb = tintArgb;
  }
}

/// Reports its own rect, in group coordinates, every time it paints.
///
/// Painting is the earliest point where the transform up to the group is
/// settled, and it is also the signal that the shape is still on screen, so
/// there is nothing to schedule and nothing to invalidate.
class RenderGlassMember extends RenderProxyBox {
  RenderGlassMember(
    this._registry,
    this._cornerRadius,
    this._interactive,
    this._tintArgb,
  );

  final Object _id = Object();

  GlassGroupRegistry _registry;
  set registry(GlassGroupRegistry value) {
    if (value == _registry) return;
    _registry.remove(_id);
    _registry = value;
    markNeedsPaint();
  }

  double _cornerRadius;
  set cornerRadius(double value) {
    if (value == _cornerRadius) return;
    _cornerRadius = value;
    markNeedsPaint();
  }

  bool _interactive;
  set interactive(bool value) {
    if (value == _interactive) return;
    _interactive = value;
    markNeedsPaint();
  }

  int? _tintArgb;
  set tintArgb(int? value) {
    if (value == _tintArgb) return;
    _tintArgb = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    _report();
    super.paint(context, offset);
  }

  void _report() {
    final RenderBox? group = _registry.groupBox;
    if (group == null || !group.attached || !group.hasSize) return;
    _registry.put(
      _id,
      GlassShape(
        rect: MatrixUtils.transformRect(
          getTransformTo(group),
          Offset.zero & size,
        ),
        cornerRadius: _cornerRadius,
        tintArgb: _tintArgb,
        interactive: _interactive,
      ),
    );
  }

  @override
  void detach() {
    _registry.remove(_id);
    super.detach();
  }

  @override
  void dispose() {
    _registry.remove(_id);
    super.dispose();
  }
}
