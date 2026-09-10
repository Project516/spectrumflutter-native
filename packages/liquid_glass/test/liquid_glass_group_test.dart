import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';

void main() {
  testWidgets('renders its child off Apple platforms', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlassGroup(
          spacing: 24,
          child: LiquidGlass(cornerRadius: 8, child: Text('content')),
        ),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
    expect(find.byType(AppKitView), findsNothing);
  });

  testWidgets('members share the group container instead of one view each', (
    tester,
  ) async {
    final _FakePlatformViews platformViews = _FakePlatformViews(tester);
    addTearDown(platformViews.dispose);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlassGroup(
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 10,
                top: 20,
                width: 100,
                height: 40,
                child: LiquidGlass(cornerRadius: 12),
              ),
              Positioned(
                left: 10,
                top: 200,
                width: 100,
                height: 40,
                child: LiquidGlass(cornerRadius: 12),
              ),
            ],
          ),
        ),
      ),
    );

    // One platform view for the container, none for the two members.
    expect(find.byType(UiKitView), findsOneWidget);
    expect(platformViews.created, hasLength(1));
    expect(
      platformViews.viewTypes.single,
      'org.spectrum3847.liquid_glass/group',
    );

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mounts an AppKit container on macOS', (tester) async {
    final _FakePlatformViews platformViews = _FakePlatformViews(tester);
    addTearDown(platformViews.dispose);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlassGroup(child: LiquidGlass()),
      ),
    );

    expect(find.byType(AppKitView), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('sends each member rect in group coordinates', (tester) async {
    final _FakePlatformViews platformViews = _FakePlatformViews(tester);
    addTearDown(platformViews.dispose);

    // Reset inline at the end of the test rather than in a tearDown: the
    // binding checks foundation debug variables before tearDowns run.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    Widget build(double secondTop) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: LiquidGlassGroup(
            spacing: 24,
            child: Stack(
              children: <Widget>[
                const Positioned(
                  left: 10,
                  top: 20,
                  width: 100,
                  height: 40,
                  child: LiquidGlass(cornerRadius: 12),
                ),
                Positioned(
                  left: 10,
                  top: secondTop,
                  width: 100,
                  height: 40,
                  child: const LiquidGlass(cornerRadius: 12, interactive: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(200));
    // The container view is created asynchronously, so the registry has no
    // channel to talk to until it settles.
    await tester.pumpAndSettle();
    final _ShapeRecorder shapes = _ShapeRecorder(
      tester,
      platformViews.ids.single,
    );
    addTearDown(shapes.dispose);

    // Move the second member: any change re-sends the whole shape list.
    await tester.pumpWidget(build(80));
    await tester.pump();

    expect(shapes.last, isNotNull);
    expect(shapes.last!['spacing'], 24.0);
    final List<Object?> sent = shapes.last!['shapes']! as List<Object?>;
    expect(sent, hasLength(2));

    final Map<Object?, Object?> first = sent.first! as Map<Object?, Object?>;
    expect(first['x'], 10.0);
    expect(first['y'], 20.0);
    expect(first['width'], 100.0);
    expect(first['height'], 40.0);
    expect(first['cornerRadius'], 12.0);
    expect(first['interactive'], isFalse);

    final Map<Object?, Object?> second = sent.last! as Map<Object?, Object?>;
    expect(second['y'], 80.0);
    expect(second['interactive'], isTrue);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('drops a member that leaves the tree', (tester) async {
    final _FakePlatformViews platformViews = _FakePlatformViews(tester);
    addTearDown(platformViews.dispose);

    // Reset inline at the end of the test rather than in a tearDown: the
    // binding checks foundation debug variables before tearDowns run.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    Widget build(bool showSecond) => Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 300,
          height: 400,
          child: LiquidGlassGroup(
            child: Stack(
              children: <Widget>[
                const Positioned(
                  left: 0,
                  top: 0,
                  width: 50,
                  height: 50,
                  child: LiquidGlass(),
                ),
                if (showSecond)
                  const Positioned(
                    left: 0,
                    top: 100,
                    width: 50,
                    height: 50,
                    child: LiquidGlass(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(build(true));
    await tester.pumpAndSettle();
    final _ShapeRecorder shapes = _ShapeRecorder(
      tester,
      platformViews.ids.single,
    );
    addTearDown(shapes.dispose);

    await tester.pumpWidget(build(false));
    await tester.pump();

    expect(shapes.last!['shapes'], hasLength(1));

    debugDefaultTargetPlatformOverride = null;
  });
}

/// Answers the platform-views channel, which no test host can, and records the
/// ids handed out so a test can listen on the container's own channel.
class _FakePlatformViews {
  _FakePlatformViews(this._tester) {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (MethodCall call) async {
        if (call.method == 'create') {
          created.add(Map<Object?, Object?>.from(call.arguments as Map));
        }
        return null;
      },
    );
  }

  final WidgetTester _tester;
  final List<Map<Object?, Object?>> created = <Map<Object?, Object?>>[];

  List<int> get ids =>
      created.map((Map<Object?, Object?> c) => c['id']! as int).toList();

  List<String> get viewTypes => created
      .map((Map<Object?, Object?> c) => c['viewType']! as String)
      .toList();

  void dispose() {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
  }
}

/// Captures what the group pushes down its own per-view channel.
class _ShapeRecorder {
  _ShapeRecorder(this._tester, int viewId)
    : _channel = MethodChannel('liquid_glass/group_$viewId') {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (
      MethodCall call,
    ) async {
      if (call.method == 'setShapes') {
        last = Map<Object?, Object?>.from(call.arguments as Map);
      }
      return null;
    });
  }

  final WidgetTester _tester;
  final MethodChannel _channel;
  Map<Object?, Object?>? last;

  void dispose() {
    _tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _channel,
      null,
    );
  }
}
