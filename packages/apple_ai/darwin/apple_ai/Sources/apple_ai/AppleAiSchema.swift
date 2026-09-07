import Foundation

#if canImport(FoundationModels)
  import FoundationModels

  /// Builds a `GenerationSchema` at runtime from the JSON Schema a Dart tool
  /// already describes itself with.
  ///
  /// This is what makes a tool registry assembled in Dart usable by
  /// `FoundationModels`, whose `Tool` protocol otherwise wants a
  /// compile-time `@Generable` Swift type. `DynamicGenerationSchema` is the
  /// runtime equivalent, so the bridge is a translation rather than a
  /// redesign.
  ///
  /// Only the subset of JSON Schema the app's tools actually use is
  /// supported: an object of typed properties, string enums, arrays, and the
  /// four scalar types. Anything unrecognised becomes a string, which is the
  /// lenient choice on purpose: a tool with one odd argument should still be
  /// callable rather than disappearing from the model's options.
  @available(iOS 26.0, macOS 26.0, *)
  enum AppleAiSchema {
    static func generationSchema(
      name: String,
      description: String?,
      json: [String: Any]
    ) throws -> GenerationSchema {
      let root = dynamicSchema(name: name, description: description, json: json)
      return try GenerationSchema(root: root, dependencies: [])
    }

    static func dynamicSchema(
      name: String,
      description: String?,
      json: [String: Any]
    ) -> DynamicGenerationSchema {
      if let choices = json["enum"] as? [Any] {
        let strings = choices.map { "\($0)" }
        if !strings.isEmpty {
          return DynamicGenerationSchema(
            name: name, description: description, anyOf: strings)
        }
      }

      switch json["type"] as? String {
      case "object":
        let properties = json["properties"] as? [String: Any] ?? [:]
        let required = Set((json["required"] as? [String] ?? []))
        // Sorted so the schema handed to the model is stable between runs;
        // a dictionary's order is not.
        let fields = properties.keys.sorted().map { key -> DynamicGenerationSchema.Property in
          let field = properties[key] as? [String: Any] ?? [:]
          return DynamicGenerationSchema.Property(
            name: key,
            description: field["description"] as? String,
            schema: dynamicSchema(
              name: "\(name)_\(key)",
              description: field["description"] as? String,
              json: field),
            isOptional: !required.contains(key))
        }
        return DynamicGenerationSchema(
          name: name, description: description, properties: fields)

      case "array":
        let items = json["items"] as? [String: Any] ?? ["type": "string"]
        return DynamicGenerationSchema(
          arrayOf: dynamicSchema(
            name: "\(name)_item", description: nil, json: items))

      case "integer":
        return DynamicGenerationSchema(type: Int.self)
      case "number":
        return DynamicGenerationSchema(type: Double.self)
      case "boolean":
        return DynamicGenerationSchema(type: Bool.self)
      default:
        return DynamicGenerationSchema(type: String.self)
      }
    }
  }
#endif
