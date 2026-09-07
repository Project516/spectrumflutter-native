import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass/liquid_glass.dart';

void main() {
  // These run on the Linux/macOS test host, so they cover the off-iOS path:
  // the widget has to degrade to its child rather than trying to mount a
  // platform view that does not exist.
  testWidgets('renders its child off iOS', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: LiquidGlass(cornerRadius: 16, child: Text('content')),
      ),
    );

    expect(find.text('content'), findsOneWidget);
  });

  testWidgets('collapses to nothing off iOS with no child', (tester) async {
    // Centered so the incoming constraints are loose: as the root widget it
    // would be handed tight screen-sized constraints and fill them.
    await tester.pumpWidget(const Center(child: LiquidGlass()));

    expect(tester.getSize(find.byType(LiquidGlass)), Size.zero);
  });

  test('reports unsupported off iOS', () async {
    expect(await liquidGlassSupported(), isFalse);
    expect(await iosSystemVersion(), isNull);
  });
}
