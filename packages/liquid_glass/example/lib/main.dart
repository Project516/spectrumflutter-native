import 'package:flutter/material.dart';
import 'package:liquid_glass/liquid_glass.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid Glass spike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const SpikeScreen(),
    );
  }
}

/// One question: does a UIKit glass view sample Flutter-drawn content as its
/// backdrop? Everything on this screen is painted by Flutter, so if the glass
/// panels come back frosted-but-empty, the answer is no and the feature is
/// dead until Flutter ships its own.
class SpikeScreen extends StatefulWidget {
  const SpikeScreen({super.key});

  @override
  State<SpikeScreen> createState() => _SpikeScreenState();
}

class _SpikeScreenState extends State<SpikeScreen> {
  String _status = 'checking';
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  Future<void> _probe() async {
    final supported = await liquidGlassSupported();
    final version = await systemVersion();
    if (!mounted) return;
    setState(() {
      _status = supported
          ? 'Liquid Glass available (OS ${version ?? "?"})'
          : 'not available (OS ${version ?? "n/a"}), showing fallback';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _LoudBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _status,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                // The panel case: glass floating over painted content. If the
                // stripes below are visible through it, refracted, the
                // backdrop sampling works.
                SizedBox(
                  height: 140,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LiquidGlass(
                      cornerRadius: 28,
                      child: Center(
                        child: Text(
                          'glass panel',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // The hit-testing case: a Flutter button drawn on top of a
                // non-interactive glass surface still has to receive taps.
                SizedBox(
                  height: 72,
                  child: LiquidGlass(
                    cornerRadius: 20,
                    child: Center(
                      child: FilledButton(
                        onPressed: () => setState(() => _taps++),
                        child: Text('taps reach Flutter: $_taps'),
                      ),
                    ),
                  ),
                ),
                // The chrome case: content scrolling underneath a fixed bar.
                Expanded(
                  child: Stack(
                    children: <Widget>[
                      ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: 40,
                        itemBuilder: (context, i) =>
                            ListTile(title: Text('scrolling row $i')),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        height: 64,
                        child: LiquidGlass(
                          cornerRadius: 32,
                          child: const Center(child: Text('fixed glass bar')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Deliberately high-contrast and Flutter-painted, so an empty backdrop is
/// unmistakable rather than a judgement call.
class _LoudBackdrop extends StatelessWidget {
  const _LoudBackdrop();

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
      child: Column(
        children: List<Widget>.generate(
          12,
          (i) => Expanded(
            child: Container(
              color: i.isEven
                  ? const Color(0x33000000)
                  : const Color(0x33FFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
