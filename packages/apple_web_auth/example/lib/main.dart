import 'package:apple_web_auth/apple_web_auth.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

/// Exercises the plugin's whole surface: one sign-in round trip, and each
/// way it can end.
class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  String _result = '';

  Future<void> _signIn() async {
    setState(() => _result = 'opening');
    try {
      final callback = await appleWebAuthenticate(
        url: Uri.parse('https://example.com/authorize'),
        callbackScheme: 'appleWebAuthExample',
      );
      setState(() => _result = 'came back with $callback');
    } on AppleWebAuthCancelled {
      setState(() => _result = 'cancelled');
    } on AppleWebAuthException catch (error) {
      setState(() => _result = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('apple_web_auth')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Supported here: $appleWebAuthSupported'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _signIn, child: const Text('Sign in')),
              const SizedBox(height: 16),
              Text(_result),
            ],
          ),
        ),
      ),
    );
  }
}
