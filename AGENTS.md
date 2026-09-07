# Agent Guide

`spectrumflutter-native` holds native Flutter plugins for the Spectrum apps
(SpectrumStrategy, SpectrumPit) and exists mainly to compile their Swift for
free. It is public so GitHub does not bill macOS Actions minutes, which in the
private app repos cost 10x against a capped monthly budget.

## Direction

This repo is a compile gate, not a product. Nothing ships from here. When a
tradeoff is unclear, optimize for finding a native build error in one cheap CI
run over anything else, and keep each plugin small enough that the app repos
can adopt or drop it without negotiation.

Visual confirmation never happens here. A plugin is looked at in the app that
consumes it, on that app's nightly AltStore build.

## Repo-specific rules

- **Pushing straight to `main` is fine here** (maintainer, 2026-09-07). This
  is the second exception to the global never-push-to-a-default-branch rule,
  alongside `agent-hq`. There is no review bot on this repo and no shipped
  artifact to protect. Every other repo, including the app repos and the
  tag-pinned client packages, still goes through a PR.
- **A tag means a release.** The app repos pin plugins by git tag, so a bump
  needs the version, the changelog, the tag and a `gh release create`, all of
  it or none. Tags are repo-wide rather than per package: one tag, and each
  app repo pins whichever package it consumes at it.
- Run the Dart gates locally before pushing. The Apple builds are the only
  part that needs CI. Commands are in `README.md`.

## Glossary

- Plugin: one directory under `packages/`, a Flutter plugin package with its
  own `pubspec.yaml`, podspec and example app.
- Compile gate: the `build ios` and `build macos` CI jobs. They build the
  example and then prove the plugin was actually linked in, because a build
  can go green while a plugin is absent.
- Liquid Glass: Apple's iOS 26 material, `UIGlassEffect`. Flutter has no
  support for it ([flutter/flutter#170310](https://github.com/flutter/flutter/issues/170310)),
  which is why `packages/liquid_glass` exists.
- Foundation model: Apple's on-device LLM, reached through the
  `FoundationModels` framework on iOS 26 / macOS 26. `packages/apple_ai`
  wraps it. It is not CoreML: CoreML runs a model you bring, this one ships
  with the OS.
