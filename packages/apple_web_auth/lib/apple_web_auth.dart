/// `ASWebAuthenticationSession` as an OAuth redirect listener.
///
/// The mobile answer to a loopback redirect. A desktop app can bind
/// `127.0.0.1` and have the browser redirect to it (RFC 8252); an iPhone
/// cannot rely on that, so the OS runs the browser and hands the app back a
/// URL on a scheme it registered.
///
/// The app has to declare that scheme in `Info.plist` under
/// `CFBundleURLTypes`, or the callback never arrives.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The method channel the native side listens on. Exposed so a test can
/// answer it.
@visibleForTesting
const MethodChannel appleWebAuthChannel = MethodChannel(
  'org.spectrum3847.apple_web_auth',
);

bool get _isApple =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Whether this platform can run a session at all.
bool get appleWebAuthSupported => _isApple;

/// Opens [url] in a system browser sheet and returns the callback URL the
/// provider redirected to, which carries the authorization code.
///
/// [callbackScheme] is the custom URL scheme the redirect uses, without the
/// `://`. It has to be registered in the app's `Info.plist`, and it has to
/// match the `redirect_uri` sent to the provider.
///
/// Throws [AppleWebAuthCancelled] when the person closed the sheet, which is
/// an ordinary outcome rather than a failure, and [AppleWebAuthException] for
/// anything else.
Future<Uri> appleWebAuthenticate({
  required Uri url,
  required String callbackScheme,
}) async {
  if (!_isApple) {
    throw const AppleWebAuthException(
      'A browser sign-in sheet is an Apple platform feature.',
    );
  }
  final String? callback;
  try {
    callback = await appleWebAuthChannel.invokeMethod<String>('authenticate', {
      'url': url.toString(),
      'callbackScheme': callbackScheme,
    });
  } on PlatformException catch (error) {
    if (error.code == 'cancelled') {
      throw const AppleWebAuthCancelled();
    }
    throw AppleWebAuthException(error.message ?? 'Sign-in failed.');
  } on MissingPluginException {
    throw const AppleWebAuthException(
      'A browser sign-in sheet is an Apple platform feature.',
    );
  }
  final parsed = callback == null ? null : Uri.tryParse(callback);
  if (parsed == null) {
    throw const AppleWebAuthException('Sign-in returned nothing to read.');
  }
  return parsed;
}

/// The person closed the sign-in sheet. Ordinary, and worth telling apart
/// from a failure: there is nothing to report and nothing to retry.
class AppleWebAuthCancelled implements Exception {
  const AppleWebAuthCancelled();

  @override
  String toString() => 'AppleWebAuthCancelled';
}

/// Sign-in could not finish. Carries text fit to show a person.
class AppleWebAuthException implements Exception {
  const AppleWebAuthException(this.message);

  final String message;

  @override
  String toString() => 'AppleWebAuthException: $message';
}
