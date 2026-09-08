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

/// Apple's on-device foundation model (Apple Intelligence), exposed to
/// Flutter.
///
/// The model ships with the OS: nothing is downloaded, nothing leaves the
/// device, and there is no key and no request budget. It is only there on
/// iOS 26 / macOS 26 with Apple Intelligence turned on and on hardware that
/// supports it, which is why every caller asks `availability` first.
///
/// Two shapes of call:
///
/// * **One shot.** No `sessionId`, one `LanguageModelSession` per call, no
///   memory of the last. What a generated summary needs.
/// * **Conversation.** A `sessionId` keeps the session, and with it the
///   transcript, alive between calls, which is what makes a chat a chat
///   rather than a series of unrelated questions. The caller closes it when
///   the conversation ends.
///
/// Tools are attached when a session is created, and their implementations
/// live in Dart: `call` comes back over this channel as `callTool`. See
/// `AppleAiSchema` for how a Dart tool's JSON Schema becomes something
/// `FoundationModels` will accept.
public class AppleAiPlugin: NSObject, FlutterPlugin {
  static let channelName = "org.spectrum3847.apple_ai"

  private var channel: FlutterMethodChannel?

  /// Live conversations by id. Only touched on the platform thread, which is
  /// where `handle` runs, so it needs no lock of its own.
  private var sessions: [String: Any] = [:]

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = AppleAiPlugin()
    instance.channel = channel
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "availability":
      result(AppleAiPlugin.availability())
    case "closeSession":
      let args = call.arguments as? [String: Any]
      if let id = args?["sessionId"] as? String {
        sessions.removeValue(forKey: id)
      }
      result(nil)
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
        sessionId: args["sessionId"] as? String,
        tools: args["tools"] as? [[String: Any]] ?? [],
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

    /// The session for this call: an existing conversation, a new one kept
    /// under [sessionId], or a throwaway when there is no id.
    ///
    /// Tools and instructions apply at creation, so changing either mid
    /// conversation needs a new session. That is the framework's shape, not a
    /// simplification: the transcript a session holds was produced under the
    /// instructions it was made with.
    @available(iOS 26.0, macOS 26.0, *)
    private func session(
      id: String?,
      instructions: String?,
      tools: [[String: Any]]
    ) -> LanguageModelSession {
      if let id, let existing = sessions[id] as? LanguageModelSession {
        return existing
      }

      let bridged = tools.compactMap { spec -> AppleAiBridgedTool? in
        guard let name = spec["name"] as? String else { return nil }
        let parameters = spec["parameters"] as? [String: Any] ?? ["type": "object"]
        guard
          let schema = try? AppleAiSchema.generationSchema(
            name: name,
            description: spec["description"] as? String,
            json: parameters)
        else {
          // One tool with a schema the framework rejects must not take the
          // whole conversation with it. Dropping it leaves the model the
          // rest.
          return nil
        }
        return AppleAiBridgedTool(
          name: name,
          description: spec["description"] as? String ?? "",
          parameters: schema,
          invoke: { [weak self] name, argumentsJson in
            await self?.callDartTool(name: name, argumentsJson: argumentsJson)
              ?? "Error: the app is no longer listening for tool calls."
          })
      }

      let created: LanguageModelSession
      if let instructions, !instructions.isEmpty {
        created = LanguageModelSession(tools: bridged) { instructions }
      } else {
        created = LanguageModelSession(tools: bridged)
      }
      if let id {
        sessions[id] = created
      }
      return created
    }

    /// Runs a tool by asking Dart, where every tool in this app is
    /// implemented. Never throws: a failure comes back as text the model can
    /// read and react to.
    @available(iOS 26.0, macOS 26.0, *)
    private func callDartTool(name: String, argumentsJson: String) async -> String {
      await withCheckedContinuation { continuation in
        // invokeMethod has to be called on the platform thread; the model
        // finished on whichever one it liked.
        DispatchQueue.main.async { [weak self] in
          guard let channel = self?.channel else {
            continuation.resume(
              returning: "Error: the app is no longer listening for tool calls.")
            return
          }
          channel.invokeMethod(
            "callTool",
            arguments: ["name": name, "arguments": argumentsJson]
          ) { answer in
            if let error = answer as? FlutterError {
              continuation.resume(
                returning: "Error: \(error.message ?? "the tool failed.")")
            } else if let text = answer as? String {
              continuation.resume(returning: text)
            } else {
              continuation.resume(
                returning: "Error: the app did not run this tool.")
            }
          }
        }
      }
    }
  #endif

  private func respond(
    prompt: String,
    instructions: String?,
    temperature: Double?,
    sessionId: String?,
    tools: [[String: Any]],
    result: @escaping FlutterResult
  ) {
    #if canImport(FoundationModels)
      if #available(iOS 26.0, macOS 26.0, *) {
        let session = session(id: sessionId, instructions: instructions, tools: tools)
        Task {
          do {
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
