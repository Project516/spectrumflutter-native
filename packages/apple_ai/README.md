# apple_ai

Apple's on-device foundation model (Apple Intelligence) as one text-in /
text-out call.

```dart
final availability = await appleAiAvailability();
if (availability.isAvailable) {
  final answer = await appleAiRespond(
    prompt: 'Which of these teams climbs most reliably?',
    instructions: 'Answer in two sentences.',
  );
}
```

The model ships with the OS: nothing is downloaded, nothing leaves the device,
there is no key and no request budget. That makes it a good offline fallback
and a bad primary, because it is a small model and it is only there on some
devices.

## Things worth knowing before using it

- **Ask `appleAiAvailability()` first, every time.** The answer changes over
  the life of an install: Apple Intelligence is a Settings toggle and the
  model downloads in the background. `AppleAiUnavailableReason` separates the
  four cases because they need different things from a person, and each one
  carries a `message` fit to show.
- **It needs iOS 26 / macOS 26 and hardware that supports Apple
  Intelligence.** Everywhere else, including Android, Windows, Linux and the
  web, availability answers `unsupportedOs` without touching the channel.
- **One call is one session with no memory.** A caller holding a conversation
  folds the earlier turns into the prompt itself.
- **The model has its own guardrails.** A prompt it declines comes back as an
  `AppleAiException`, not as text, so treat a failure as "no answer" rather
  than an error worth showing as a broken screen.
