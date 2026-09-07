import Foundation

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

// Compiled out entirely on an Xcode without the iOS 26 / macOS 26 SDKs, so
// the plugin still builds there and answers "unsupportedOs" at runtime.
#if canImport(FoundationModels)
  import FoundationModels
#endif

/// Apple's on-device foundation model (Apple Intelligence), exposed to Flutter
/// as one text-in / text-out call.
///
/// The model ships with the OS: nothing is downloaded, nothing leaves the
/// device, and there is no key and no request budget. It is only there on
/// iOS 26 / macOS 26 with Apple Intelligence turned on and on hardware that
/// supports it, which is why every caller asks `availability` first.
///
/// One call is one `LanguageModelSession`. Multi-turn context is the caller's
/// job: it folds prior turns into the prompt, so this side stays a pure
/// function and nothing has to be kept alive between calls.
public class AppleAiPlugin: NSObject, FlutterPlugin {
  static let channelName = "org.spectrum3847.apple_ai"

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    registrar.addMethodCallDelegate(AppleAiPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(AppleAiPlugin.availability())
    case "respond":
      guard let args = call.arguments as? [String: Any],
        let prompt = args["prompt"] as? String,
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(
          FlutterError(
            code: "bad_arguments",
            message: "respond needs a non-empty prompt.",
            details: nil))
        return
      }
      respond(
        prompt: prompt,
        instructions: args["instructions"] as? String,
        temperature: args["temperature"] as? Double,
        result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// `["available": Bool, "reason": String]`. The reason is empty when the
  /// model is available, and otherwise names which of the four things is
  /// missing, because they need different answers from a person: an
  /// ineligible device is permanent, a disabled Apple Intelligence is a
  /// Settings toggle, and a model still downloading fixes itself.
  private static func availability() -> [String: Any] {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        switch SystemLanguageModel.default.availability {
        case .available:
          return ["available": true, "reason": ""]
        case .unavailable(let reason):
          return ["available": false, "reason": name(of: reason)]
        @unknown default:
          return ["available": false, "reason": "unknown"]
        }
      }
    #endif
    return ["available": false, "reason": "unsupportedOs"]
  }

  #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private static func name(
      of reason: SystemLanguageModel.Availability.UnavailableReason
    ) -> String {
      switch reason {
      case .deviceNotEligible: return "deviceNotEligible"
      case .appleIntelligenceNotEnabled: return "appleIntelligenceNotEnabled"
      case .modelNotReady: return "modelNotReady"
      @unknown default: return "unknown"
      }
    }
  #endif

  private func respond(
    prompt: String,
    instructions: String?,
    temperature: Double?,
    result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        Task {
          do {
            let session: LanguageModelSession
            if let instructions, !instructions.isEmpty {
              session = LanguageModelSession { instructions }
            } else {
              session = LanguageModelSession()
            }
            let response = try await session.respond(
              to: prompt,
              options: GenerationOptions(temperature: temperature))
            let text = response.content
            // A method channel result belongs on the platform thread; the
            // response arrives on whichever one the model finished on.
            DispatchQueue.main.async { result(text) }
          } catch {
            DispatchQueue.main.async {
              result(
                FlutterError(
                  code: "generation_failed",
                  message: error.localizedDescription,
                  details: nil))
            }
          }
        }
        return
      }
    #endif
    result(
      FlutterError(
        code: "unavailable",
        message: "The on-device model needs iOS 26 or macOS 26.",
        details: nil))
  }
}
