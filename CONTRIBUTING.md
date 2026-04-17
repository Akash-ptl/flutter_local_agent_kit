# Contributing

Thanks for your interest in improving `flutter_local_agent_kit`.

## Before opening a PR

1. Open an issue first for large changes, new features, or breaking API ideas.
2. Keep pull requests focused and easy to review.
3. Include tests or a clear explanation when behavior changes.

## Local checks

Run these before submitting:

```bash
flutter analyze
flutter test
```

If you change package metadata or publish-facing docs, also run:

```bash
flutter pub publish --dry-run
```

## Pull request guidance

Please include:

* a short summary of the change
* why the change is needed
* terminal output or logs when UI or tooling behavior changes
* notes about compatibility risks, if any

## Code style

Follow the existing Dart and Flutter style in the repository and prefer small, readable API changes over broad rewrites.
