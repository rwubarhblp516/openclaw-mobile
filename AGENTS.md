# Repository Guidelines

## Project Structure & Module Organization
This repository is a Flutter app with a Rust backend bridge.
- `lib/`: Dart application code (`app.dart`, UI in `lib/src/ui/`, services in `lib/src/services/`).
- `lib/src/rust/`: Generated Flutter Rust Bridge (FRB) Dart bindings. Treat as generated code.
- `rust_lib/src/`: Rust implementation (`api/` modules and FRB entrypoints).
- `test/`: Flutter widget/unit tests.
- `integration_test/`: end-to-end state and gateway behavior tests.
- Platform folders: `android/`, `ios/`, `macos/`, `linux/`, `windows/`, `web/`.

## Build, Test, and Development Commands
Run from repository root unless noted.
- `flutter pub get`: install Dart/Flutter dependencies.
- `flutter run`: run the app on a connected device/emulator.
- `flutter analyze`: static analysis using `flutter_lints`.
- `flutter test`: run unit/widget tests in `test/`.
- `flutter test integration_test`: run integration suite.
- `cargo check --manifest-path rust_lib/Cargo.toml`: validate Rust code compiles.
- `cargo test --manifest-path rust_lib/Cargo.toml`: run Rust tests (when present).
- `flutter_rust_bridge_codegen generate`: regenerate FRB bindings from `flutter_rust_bridge.yaml` after Rust API changes.

## Coding Style & Naming Conventions
- Follow Dart analyzer/lints from `analysis_options.yaml` (`package:flutter_lints/flutter.yaml`).
- Use `dart format .` for Dart and `cargo fmt --manifest-path rust_lib/Cargo.toml` for Rust before committing.
- Dart naming: `PascalCase` for types, `camelCase` for members, `snake_case.dart` filenames.
- Rust naming: `snake_case` for modules/functions, `CamelCase` for structs/enums.
- Do not hand-edit generated files (for example `lib/src/rust/frb_generated*.dart`, `rust_lib/src/frb_generated.rs`, `*.freezed.dart`).
- All user-facing strings must be in Chinese (`zh-CN`) by default.
- English user-facing strings are not allowed unless technically impossible (for example protocol-required literals or third-party immutable output).

## Testing Guidelines
- Keep tests close to behavior: widget/unit tests in `test/`, integration flows in `integration_test/`.
- Name test files with `_test.dart` (example: `gateway_state_test.dart`).
- Prefer deterministic tests with injected fakes/mocks (see `MockGatewayService`).
- Add or update tests for all user-visible behavior changes and protocol/state transitions.

## Commit & Pull Request Guidelines
- Use Conventional Commits, as seen in history: `feat: ...`, `fix: ...`, `test: ...`, `chore: ...`.
- Keep commits scoped and atomic; separate refactors from behavior changes.
- PRs should include a concise summary of intent and impacted areas.
- PRs should link the related issue/task when available.
- PRs should include test evidence (for example `flutter test` and integration output).
- PRs should attach screenshots or video for UI changes.
