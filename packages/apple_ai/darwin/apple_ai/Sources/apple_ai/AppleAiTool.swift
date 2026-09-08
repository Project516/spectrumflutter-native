import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// A tool the model may call, whose implementation lives in Dart.
  ///
  /// `Arguments` is `GeneratedContent` rather than a `@Generable` struct
  /// because the tool list is assembled at runtime; see `AppleAiSchema` for
  /// the schema half of that. `call` hands the arguments back over the method
  /// channel as JSON and waits for the app to answer.
  ///
  /// It never throws. A tool that failed still has to produce text the model
  /// can read, or the conversation ends on an error the person asking cannot
  /// act on. Returning the failure as the tool's result lets the model say
  /// what went wrong, or try a different tool.
  @available(iOS 26.0, macOS 26.0, *)
  struct AppleAiBridgedTool: Tool {
    typealias Arguments = GeneratedContent

    let name: String
    let description: String
    let parameters: GenerationSchema
    let invoke: @Sendable (String, String) async -> String

    func call(arguments: GeneratedContent) async -> String {
      await invoke(name, arguments.jsonString)
    }
  }
#endif
