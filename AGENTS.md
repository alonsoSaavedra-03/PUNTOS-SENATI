# Repository Guidelines

## Project Structure

This is a Flutter application targeting Android and Web. Keep app startup, theme, and GoRouter configuration in `lib/main.dart`; persistent local data access belongs in `lib/data/`; and user-facing modules belong in `lib/features/`. Platform runners and web metadata live in `android/` and `web/`. Automated checks are in `test/`.

## Build, Run, and Verify

- `flutter pub get` resolves Dart and Flutter dependencies.
- `flutter run -d edge` runs the web app locally with Microsoft Edge; use `-d chrome` when Chrome is installed.
- `flutter analyze` checks Dart code and lints.
- `flutter test` runs unit and widget tests.
- `flutter build web` creates the deployable web bundle in `build/web`.
- `flutter build apk --release` creates an Android release APK under `build/app/outputs/flutter-apk/`.

Run commands from the repository root. Do not claim a build or test passed unless its command completed successfully.

## Architecture and Data

Use Flutter/Dart exclusively for the interface. Prefer Material 3 widgets, responsive layouts, Riverpod providers, and GoRouter paths for new screens. Keep data operations behind the local repository/store rather than writing persistence logic in widgets. Current records use `SharedPreferencesAsync` with JSON serialization so they persist on Android and Web. Do not describe the local outbox as server synchronization; no API is connected.

## Style and Testing

Use `dart format` on changed Dart files, descriptive `snake_case.dart` filenames, and `UpperCamelCase` types. Keep screens and data logic in focused files. Add tests under `test/` for business rules and persistence; name them `*_test.dart`. Cover duplicate prevention, validation, derived totals, and platform-sensitive behavior when changing those areas.

## Pull Requests

Use short, imperative commit subjects (for example, `Add session attendance`). PRs should state user-visible changes, note local data or migration impacts, link related work, and list commands actually run. Include screenshots for significant UI changes.

## Configuration

Never commit credentials or real student data. Keep local-only configuration out of source control and use synthetic records for development examples.
