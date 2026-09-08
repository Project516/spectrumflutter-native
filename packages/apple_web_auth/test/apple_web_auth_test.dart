import 'package:apple_web_auth/apple_web_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  void mockNative(Object? Function(MethodCall call) answer) {
    messenger.setMockMethodCallHandler(appleWebAuthChannel, (call) async {
      calls.add(call);
      return answer(call);
    });
  }

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(appleWebAuthChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('returns the callback url the provider redirected to', () async {
    mockNative((_) => 'spectrumstrategy://mcp?code=abc&state=xyz');

    final callback = await appleWebAuthenticate(
      url: Uri.parse('https://example.test/authorize?client_id=1'),
      callbackScheme: 'spectrumstrategy',
    );

    expect(callback.queryParameters['code'], 'abc');
    expect(calls.single.arguments, <String, Object?>{
      'url': 'https://example.test/authorize?client_id=1',
      'callbackScheme': 'spectrumstrategy',
    });
  });

  test('a closed sheet is cancellation, not failure', () async {
    mockNative(
      (_) => throw PlatformException(code: 'cancelled', message: 'closed'),
    );

    expect(
      () => appleWebAuthenticate(
        url: Uri.parse('https://example.test/authorize'),
        callbackScheme: 'spectrumstrategy',
      ),
      throwsA(isA<AppleWebAuthCancelled>()),
    );
  });

  test('any other native failure carries its message', () async {
    mockNative(
      (_) => throw PlatformException(code: 'failed', message: 'no window'),
    );

    expect(
      () => appleWebAuthenticate(
        url: Uri.parse('https://example.test/authorize'),
        callbackScheme: 'spectrumstrategy',
      ),
      throwsA(
        isA<AppleWebAuthException>().having(
          (e) => e.message,
          'message',
          'no window',
        ),
      ),
    );
  });

  test('off an Apple platform it refuses without a channel call', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    mockNative((_) => fail('the channel must not be touched off Apple'));

    expect(appleWebAuthSupported, isFalse);
    expect(
      () => appleWebAuthenticate(
        url: Uri.parse('https://example.test/authorize'),
        callbackScheme: 'spectrumstrategy',
      ),
      throwsA(isA<AppleWebAuthException>()),
    );
    expect(calls, isEmpty);
  });
}
