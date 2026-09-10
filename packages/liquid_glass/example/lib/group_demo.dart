import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

/// The grouping question: do two glass surfaces in one container blend into
/// each other as they approach, the way Apple's own chrome does?
///
/// The gap slider drives them together. Grouped, the two capsules should
/// stretch toward one another and fuse into a single shape before they touch.
/// Ungrouped, they stay two hard-edged capsules that simply overlap. The
/// toggle is the control: same widgets, same geometry, only the container
/// differs.
class GroupDemoScreen extends StatefulWidget {
  const GroupDemoScreen({super.key});

  @override
  State<GroupDemoScreen> createState() => _GroupDemoScreenState();
}

class _GroupDemoScreenState extends State<GroupDemoScreen> {
  double _gap = 120;
  bool _grouped = true;

  @override
  Widget build(BuildContext context) {
    // Both capsules are plain LiquidGlass. Inside a group they become shapes
    // in its container; outside one they are platform views of their own.
    final Widget shapes = Stack(
      children: <Widget>[
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: SizedBox(
              width: 220,
              height: 64,
              child: LiquidGlass(
                cornerRadius: 32,
                child: const Center(child: Text('one')),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 40 + 64 + _gap),
            child: SizedBox(
              width: 140,
              height: 64,
              child: LiquidGlass(
                cornerRadius: 32,
                child: const Center(child: Text('two')),
              ),
            ),
          ),
        ),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: const Text('glass grouping')),
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _Stripes()),
          // The group sits above the content it refracts and below the labels
          // drawn on the glass, which is what its own paint order documents.
          Positioned.fill(
            child: _grouped
                ? LiquidGlassGroup(spacing: 40, child: shapes)
                : shapes,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SwitchListTile(
                      value: _grouped,
                      onChanged: (bool v) => setState(() => _grouped = v),
                      title: const Text('grouped'),
                    ),
                    Slider(
                      value: _gap,
                      max: 200,
                      onChanged: (double v) => setState(() => _gap = v),
                    ),
                    Text('gap ${_gap.round()}'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stripes extends StatelessWidget {
  const _Stripes();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF3C0060),
            Color(0xFF00B4D8),
            Color(0xFFFFB703),
          ],
        ),
      ),
      child: Row(
        children: List<Widget>.generate(
          14,
          (int i) => Expanded(
            child: ColoredBox(
              color: i.isEven
                  ? const Color(0x33000000)
                  : const Color(0x33FFFFFF),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
