import 'package:apple_ai/apple_ai.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Exercises the whole plugin surface: what the model's availability says,
/// and one answer out of it.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _status = 'checking';
  String _answer = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final availability = await appleAiAvailability();
    if (!mounted) return;
    setState(() {
      _status = availability.isAvailable
          ? 'available'
          : availability.reason!.message;
    });
  }

  Future<void> _ask() async {
    setState(() {
      _busy = true;
      _answer = '';
    });
    try {
      final answer = await appleAiRespond(
        prompt: 'Name one thing a robot scouting app is for, in one sentence.',
        instructions: 'Answer in one short sentence.',
        temperature: 0.2,
      );
      if (mounted) setState(() => _answer = answer);
    } on AppleAiException catch (error) {
      if (mounted) setState(() => _answer = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('apple_ai')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('On-device model: $_status'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _ask,
                child: const Text('Ask'),
              ),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(child: Text(_answer))),
            ],
          ),
        ),
      ),
    );
  }
}
