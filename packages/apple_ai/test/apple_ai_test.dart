import 'package:apple_ai/apple_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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
