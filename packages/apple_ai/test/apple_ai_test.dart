import 'package:apple_ai/apple_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plays the native side calling back into Dart with a tool call, and
/// returns what Dart answered.
Future<Object?> _nativeCallsTool(Map<String, Object?> arguments) async {
  final envelope = const StandardMethodCodec().encodeMethodCall(
    MethodCall('callTool', arguments),
  );
  final reply = await TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(appleAiChannel.name, envelope, null);
  return const StandardMethodCodec().decodeEnvelope(reply!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  /// Answers the channel the way the native side would. [answer] is returned
  /// as the result; a [PlatformException] is thrown instead.
  void mockNative(Object? Function(MethodCall call) answer) {
    messenger.setMockMethodCallHandler(appleAiChannel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(appleAiChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  group('availability', () {
    test('reads an available model', () async {
      mockNative((_) => <Object?, Object?>{'available': true, 'reason': ''});

      expect((await appleAiAvailability()).isAvailable, isTrue);
      expect((await appleAiAvailability()).reason, isNull);
    });

    test('names each reason the model is unavailable', () async {
      for (final reason in <AppleAiUnavailableReason>[
        AppleAiUnavailableReason.deviceNotEligible,
        AppleAiUnavailableReason.appleIntelligenceNotEnabled,
        AppleAiUnavailableReason.modelNotReady,
        AppleAiUnavailableReason.unsupportedOs,
      ]) {
        mockNative(
          (_) => <Object?, Object?>{'available': false, 'reason': reason.name},
        );

        final availability = await appleAiAvailability();
        expect(availability.isAvailable, isFalse);
        expect(availability.reason, reason);
      }
    });

    test('a reason this build does not know reads as unknown', () async {
      mockNative(
        (_) => <Object?, Object?>{'available': false, 'reason': 'somethingNew'},
      );

      expect(
        (await appleAiAvailability()).reason,
        AppleAiUnavailableReason.unknown,
      );
    });

    test(
      'is unavailable off an Apple platform, without a channel call',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        mockNative((_) => fail('the channel must not be touched off Apple'));

        expect(
          (await appleAiAvailability()).reason,
          AppleAiUnavailableReason.unsupportedOs,
        );
        expect(calls, isEmpty);
      },
    );

    test('a plugin that is not there is not a crash', () async {
      // No mock handler at all, which is what a build without the plugin does.
      expect(
        (await appleAiAvailability()).reason,
        AppleAiUnavailableReason.unsupportedOs,
      );
    });
  });

  group('tools and sessions', () {
    test('sends the tool schemas and the session id', () async {
      mockNative((_) => 'Team 3847 climbs in 9 of 11 matches.');

      await appleAiRespond(
        prompt: 'who climbs?',
        sessionId: 'chat-1',
        tools: <AppleAiTool>[
          const AppleAiTool(
            name: 'get_team_stats',
            description: 'Scouting aggregates for one team.',
            parameters: <String, dynamic>{
              'type': 'object',
              'properties': <String, dynamic>{
                'team': <String, dynamic>{'type': 'integer'},
              },
              'required': <String>['team'],
            },
          ),
        ],
      );

      final args = calls.single.arguments as Map<Object?, Object?>;
      expect(args['sessionId'], 'chat-1');
      final tools = args['tools']! as List<Object?>;
      final tool = tools.single! as Map<Object?, Object?>;
      expect(tool['name'], 'get_team_stats');
      final parameters = tool['parameters']! as Map<Object?, Object?>;
      expect(parameters['type'], 'object');
      expect(parameters['required'], <String>['team']);
    });

    test('a tool call from the model reaches the handler', () async {
      String? sawName;
      Map<String, dynamic>? sawArguments;
      appleAiSetToolHandler((name, arguments) async {
        sawName = name;
        sawArguments = arguments;
        return 'EPA 62.4';
      });
      addTearDown(() => appleAiSetToolHandler(null));

      final answer = await _nativeCallsTool(<String, Object?>{
        'name': 'get_team_stats',
        'arguments': '{"team": 3847}',
      });

      expect(sawName, 'get_team_stats');
      expect(sawArguments, <String, dynamic>{'team': 3847});
      expect(answer, 'EPA 62.4');
    });

    test('a handler that throws answers the model instead of dying', () async {
      appleAiSetToolHandler((name, arguments) async => throw StateError('no'));
      addTearDown(() => appleAiSetToolHandler(null));

      final answer = await _nativeCallsTool(<String, Object?>{
        'name': 'get_team_stats',
        'arguments': '{}',
      });

      expect(answer, startsWith('Error:'));
    });

    test('unreadable arguments still run the tool', () async {
      Map<String, dynamic>? sawArguments;
      appleAiSetToolHandler((name, arguments) async {
        sawArguments = arguments;
        return 'ok';
      });
      addTearDown(() => appleAiSetToolHandler(null));

      await _nativeCallsTool(<String, Object?>{
        'name': 'get_team_stats',
        'arguments': 'not json',
      });

      // Empty rather than a parse failure: the tool's own validation says
      // what is missing, in words the model can act on.
      expect(sawArguments, isEmpty);
    });

    test('closing a session tells the native side', () async {
      mockNative((_) => null);

      await appleAiCloseSession('chat-1');

      expect(calls.single.method, 'closeSession');
      expect(calls.single.arguments, <String, Object?>{'sessionId': 'chat-1'});
    });

    test('closing a session off Apple is a no-op', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      mockNative((_) => fail('the channel must not be touched off Apple'));

      await appleAiCloseSession('chat-1');

      expect(calls, isEmpty);
    });
  });

  group('respond', () {
    test('sends the prompt and returns the trimmed answer', () async {
      mockNative((_) => '  three teams can climb.\n');

      final answer = await appleAiRespond(
        prompt: 'who climbs?',
        instructions: 'answer in one line',
        temperature: 0.2,
      );

      expect(answer, 'three teams can climb.');
      expect(calls.single.method, 'respond');
      expect(calls.single.arguments, <String, Object?>{
        'prompt': 'who climbs?',
        'instructions': 'answer in one line',
        'temperature': 0.2,
        'sessionId': null,
        'tools': null,
      });
    });

    test('a native failure surfaces its message', () async {
      mockNative(
        (_) => throw PlatformException(
          code: 'generation_failed',
          message: 'the model declined',
        ),
      );

      expect(
        () => appleAiRespond(prompt: 'who climbs?'),
        throwsA(
          isA<AppleAiException>().having(
            (e) => e.message,
            'message',
            'the model declined',
          ),
        ),
      );
    });

    test('an empty answer is a failure, not an empty summary', () async {
      mockNative((_) => '   ');

      expect(
        () => appleAiRespond(prompt: 'who climbs?'),
        throwsA(isA<AppleAiException>()),
      );
    });

    test('throws off an Apple platform', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;

      expect(
        () => appleAiRespond(prompt: 'who climbs?'),
        throwsA(isA<AppleAiException>()),
      );
    });
  });
}
