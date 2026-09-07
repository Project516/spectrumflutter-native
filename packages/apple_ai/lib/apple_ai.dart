/// Apple's on-device foundation model (Apple Intelligence) as text in, text
/// out, with optional tool calling and multi-turn conversations.
///
/// The model ships with the OS. Nothing is downloaded, nothing leaves the
/// device, there is no key and no request budget. In exchange it only exists
/// on iOS 26 / macOS 26, on hardware that supports Apple Intelligence, with
/// Apple Intelligence turned on, so [appleAiAvailability] is the first thing
/// a caller asks and the answer changes over the life of an install.
///
/// Two shapes of call. Without a `sessionId` each call is its own session
/// with no memory, which is what a generated summary wants. With one, the
/// session and its transcript stay alive between calls, which is what makes
/// a chat a chat; close it with [appleAiCloseSession] when the conversation
/// ends.
library;

import 'dart:convert';

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
/// [instructions] is the system prompt and [tools] the tools the model may
/// call. Both apply when a session is created, so changing either mid
/// conversation needs a new [sessionId]: the transcript a session holds was
/// produced under the instructions it was made with.
///
/// Without [sessionId] this is a single session with no memory of the last
/// call. With one, the conversation continues; end it with
/// [appleAiCloseSession].
///
/// Passing [tools] without calling [appleAiSetToolHandler] first means the
/// model asks for tools nothing answers, so set the handler once at startup.
///
/// Throws [AppleAiException] when the model refused, failed, or is not
/// available.
Future<String> appleAiRespond({
  required String prompt,
  String? instructions,
  double? temperature,
  String? sessionId,
  List<AppleAiTool>? tools,
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
      'sessionId': sessionId,
      'tools': tools?.map((tool) => tool.toJson()).toList(growable: false),
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

/// Runs a tool the model asked for, and returns text for it to read.
///
/// Never throws: a failure has to reach the model as readable text, or the
/// conversation ends on an error the person asking cannot act on. Return the
/// problem as the result and let the model say what went wrong.
typedef AppleAiToolHandler = Future<String> Function(
  String name,
  Map<String, dynamic> arguments,
);

/// One tool the model may call, described the way OpenAI-style tools already
/// are elsewhere, so a caller can hand over the schema it already has.
class AppleAiTool {
  const AppleAiTool({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;

  /// JSON Schema for the arguments. The native side turns this into a
  /// `DynamicGenerationSchema`, supporting objects, string enums, arrays and
  /// the four scalar types; anything else is treated as a string rather than
  /// dropping the tool.
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

AppleAiToolHandler? _toolHandler;
bool _handlerInstalled = false;

/// Sets what runs when the model calls a tool. Pass null to stop answering
/// tool calls.
///
/// One handler for the whole app, because a handler is a lookup by tool name
/// rather than per-conversation state, and the app has one tool registry.
void appleAiSetToolHandler(AppleAiToolHandler? handler) {
  _toolHandler = handler;
  if (_handlerInstalled) return;
  _handlerInstalled = true;
  appleAiChannel.setMethodCallHandler(_handleNativeCall);
}

Future<Object?> _handleNativeCall(MethodCall call) async {
  if (call.method != 'callTool') {
    throw MissingPluginException('apple_ai: unknown call ${call.method}');
  }
  final handler = _toolHandler;
  if (handler == null) {
    return 'Error: this app is not answering tool calls right now.';
  }
  final args = (call.arguments as Map?) ?? const <Object?, Object?>{};
  final name = args['name'] as String? ?? '';
  final raw = args['arguments'] as String? ?? '';
  Map<String, dynamic> decoded;
  try {
    final parsed = raw.trim().isEmpty ? null : jsonDecode(raw);
    decoded = parsed is Map
        ? Map<String, dynamic>.from(parsed)
        : <String, dynamic>{};
  } on FormatException {
    // The tool still runs. Its own argument validation reports the real
    // problem, in words the model can act on, which is better than refusing
    // here with a parser error.
    decoded = <String, dynamic>{};
  }
  try {
    return await handler(name, decoded);
  } catch (error) {
    return 'Error: $error';
  }
}

/// Ends a conversation started by passing [sessionId] to [appleAiRespond],
/// releasing the model session and its transcript.
///
/// Safe to call for an id that was never used or is already gone.
Future<void> appleAiCloseSession(String sessionId) async {
  if (!_isApple) return;
  try {
    await appleAiChannel.invokeMethod<void>('closeSession', {
      'sessionId': sessionId,
    });
  } on PlatformException {
    // Closing is best effort. The session dies with the app anyway, and a
    // caller tidying up after a conversation has nothing to do with a
    // failure here.
  } on MissingPluginException {
    // Same.
  }
}

/// The on-device model could not answer. Always carries text fit to show a
/// person, since that is the only thing a caller can do with it.
class AppleAiException implements Exception {
  const AppleAiException(this.message);

  final String message;

  @override
  String toString() => 'AppleAiException: $message';
}
