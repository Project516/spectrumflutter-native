## 0.1.0

- Tool calling: `appleAiRespond` takes `tools`, and `appleAiSetToolHandler`
  runs them in Dart. A tool's JSON Schema becomes a `DynamicGenerationSchema`
  at runtime, so a registry assembled in Dart works without a compile-time
  `@Generable` Swift type.
- Multi-turn conversations: pass a `sessionId` to keep a session and its
  transcript alive between calls, and `appleAiCloseSession` to end it.

## 0.0.1

- Initial `appleAiAvailability()` / `appleAiRespond()` over Apple's on-device
  foundation model (FoundationModels), on iOS 26 and macOS 26, unavailable
  everywhere else rather than broken.
