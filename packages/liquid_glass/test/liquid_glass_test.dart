import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';

void main() {
  // These run on the Linux/macOS test host, where the test binding reports
  // android as the platform, so they cover the off-Apple path: the widget has
  // to degrade to its child rather than trying to mount a platform view that
  // does not exist.
  testWidgets('renders its child off Apple platforms', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlass(cornerRadius: 16, child: Text('content')),
      ),
    );

    expect(find.text('content'), findsOneWidget);
    expect(find.byType(UiKitView), findsNothing);
    expect(find.byType(AppKitView), findsNothing);
  });

  testWidgets('collapses to nothing off Apple platforms with no child', (
    tester,
  ) async {
    // Centered so the incoming constraints are loose: as the root widget it
    // would be handed tight screen-sized constraints and fill them.
    await tester.pumpWidget(const Center(child: LiquidGlass()));

    expect(tester.getSize(find.byType(LiquidGlass)), Size.zero);
  });

  testWidgets('mounts a UIKit view on iOS and an AppKit view on macOS', (
    tester,
  ) async {
    // The platform view itself cannot be created on the test host, so the
    // platform-views channel gets a handler that answers nothing, and only the
    // widget choice is asserted.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      (call) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform_views,
        null,
      );
      debugDefaultTargetPlatformOverride = null;
    });

    // Distinct keys, or the second pump hands Flutter the identical widget
    // and nothing rebuilds.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlass(key: ValueKey('ios')),
      ),
    );
    expect(find.byType(UiKitView), findsOneWidget);

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlass(key: ValueKey('macos')),
      ),
    );
    expect(find.byType(AppKitView), findsOneWidget);
  });

  test('reports unsupported off Apple platforms', () async {
    expect(await liquidGlassSupported(), isFalse);
    expect(await systemVersion(), isNull);
  });
}
