/// Apple's on-device foundation model (Apple Intelligence) as one text-in /
/// text-out call.
///
/// The model ships with the OS. Nothing is downloaded, nothing leaves the
/// device, there is no key and no request budget. In exchange it only exists
/// on iOS 26 / macOS 26, on hardware that supports Apple Intelligence, with
/// Apple Intelligence turned on, so [appleAiAvailability] is the first thing
/// a caller asks and the answer changes over the life of an install.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The method channel the native side listens on. Exposed so a test can
/// answer it.
@visibleForTesting
const MethodChannel appleAiChannel = MethodChannel('org.spectrum3847.apple_ai');

// [defaultTargetPlatform] rather than `dart:io`'s [Platform], so a test can
// override it and so the web build needs no separate implementation.
bool get _isApple =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Why the on-device model cannot answer. Each one needs a different thing
/// from a person, which is why this is not a single boolean: an ineligible
/// device is permanent, a disabled Apple Intelligence is a Settings toggle,
/// and a model still downloading fixes itself.
enum AppleAiUnavailableReason {
  /// Not an Apple platform, or an Apple platform older than 26.
  unsupportedOs,
  deviceNotEligible,
  appleIntelligenceNotEnabled,
  modelNotReady,
  unknown;

  static AppleAiUnavailableReason fromName(String? name) =>
      AppleAiUnavailableReason.values.firstWhere(
        (reason) => reason.name == name,
        orElse: () => AppleAiUnavailableReason.unknown,
      );

  /// Wording fit to show a person, in the app's voice rather than Apple's.
  String get message => switch (this) {
    AppleAiUnavailableReason.unsupportedOs =>
      'On-device AI needs iOS 26 or macOS 26.',
    AppleAiUnavailableReason.deviceNotEligible =>
      'This device does not support Apple Intelligence.',
    AppleAiUnavailableReason.appleIntelligenceNotEnabled =>
      'Turn on Apple Intelligence in Settings to use on-device AI.',
    AppleAiUnavailableReason.modelNotReady =>
      'Apple Intelligence is still downloading its model.',
    AppleAiUnavailableReason.unknown =>
      'On-device AI is not available right now.',
  };
}

/// Whether the on-device model can answer, and why not when it cannot.
class AppleAiAvailability {
  const AppleAiAvailability.available() : isAvailable = true, reason = null;

  const AppleAiAvailability.unavailable(AppleAiUnavailableReason this.reason)
    : isAvailable = false;

  final bool isAvailable;

  /// Null when [isAvailable] is true.
  final AppleAiUnavailableReason? reason;
}

/// Whether the on-device model can answer right now.
///
/// Cheap: it reads a system property, it does not load the model. Safe to
/// call on every platform, since it answers [AppleAiUnavailableReason
/// .unsupportedOs] off Apple without touching the channel.
Future<AppleAiAvailability> appleAiAvailability() async {
  if (!_isApple) {
    return const AppleAiAvailability.unavailable(
      AppleAiUnavailableReason.unsupportedOs,
    );
  }
  final Map<Object?, Object?>? answer;
  try {
    answer = await appleAiChannel.invokeMethod<Map<Object?, Object?>>(
      'availability',
    );
  } on PlatformException {
    return const AppleAiAvailability.unavailable(
      AppleAiUnavailableReason.unknown,
    );
  } on MissingPluginException {
    return const AppleAiAvailability.unavailable(
      AppleAiUnavailableReason.unsupportedOs,
    );
  }
  if (answer?['available'] == true) {
    return const AppleAiAvailability.available();
  }
  return AppleAiAvailability.unavailable(
    AppleAiUnavailableReason.fromName(answer?['reason'] as String?),
  );
}

/// The model's answer to [prompt].
///
/// [instructions] is the system prompt, applied for this call only. A call is
/// one session with no memory of the last one, so a caller holding a
/// conversation folds the earlier turns into [prompt] itself.
///
/// Throws [AppleAiException] when the model refused, failed, or is not
/// available.
Future<String> appleAiRespond({
  required String prompt,
  String? instructions,
  double? temperature,
}) async {
  if (!_isApple) {
    throw const AppleAiException('On-device AI needs iOS 26 or macOS 26.');
  }
  final String? text;
  try {
    text = await appleAiChannel.invokeMethod<String>('respond', {
      'prompt': prompt,
      'instructions': instructions,
      'temperature': temperature,
    });
  } on PlatformException catch (error) {
    throw AppleAiException(error.message ?? 'The on-device model failed.');
  } on MissingPluginException {
    throw const AppleAiException('On-device AI needs iOS 26 or macOS 26.');
  }
  if (text == null || text.trim().isEmpty) {
    throw const AppleAiException('The on-device model sent no answer.');
  }
  return text.trim();
}

/// The on-device model could not answer. Always carries text fit to show a
/// person, since that is the only thing a caller can do with it.
class AppleAiException implements Exception {
  const AppleAiException(this.message);

  final String message;

  @override
  String toString() => 'AppleAiException: $message';
}
