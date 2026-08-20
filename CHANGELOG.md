# Changelog

All notable changes to this project will be documented in this file.

## [1.1.6] - 2026-08-20

### Changed
- Upgraded package dependencies (`mobile_rag_engine` to `^0.20.0`, `syncfusion_flutter_pdf` to `^34.2.4`, `dio` to `^5.11.0`, `llamadart` to `^0.8.19`, `mcp_dart` to `^2.4.1`, etc.) to maximize pub.dev score to 160/160.

## [1.1.5] - 2026-06-24

### Changed
- Upgraded package dependencies to support their latest stable versions.
- Expanded platform support to natively include **macOS** by removing the `permission_handler` dependency and delegating permission handling directly to `speech_to_text`.
- Documented all remaining public API constructors to achieve 100% documentation coverage.

## [1.1.4] - 2026-06-01

### Fixed
- Resolved deprecated `cacheExtent` usage in `AgentChatView` to maximize pub.dev static analysis score.
- Fixed critical message ID collision in `AgentChatView` where user messages could be overwritten when a stream failed in rapid succession.

### Changed
- Fully formatted the codebase to strict Dart code standards.

## [1.1.3] - 2026-04-27

### Fixed
- Resolved `_TypeError` crash in `AgentChatView` related to `maxScrollExtent` access before layout.
- Added safety guards to `ScrollController` listeners for improved stability.

## [1.1.2] - 2026-04-25

### Fixed
- Optimized package score to 150/150 on pub.dev.
- Removed discontinued `flutter_adaptive_scaffold` dependency.
- Updated `image_picker` to latest.
- Resolved all static analysis lints and deprecated API usages.

## [1.1.1] - 2026-04-25

### Added
- **Multimodal Vision**: Support for image analysis via `AgentChatMessage.imageBytes`.
- **Advanced RAG**: Local document ingestion with structured `SourceMetadata` and live citations.
- **MCP Service**: Connection to Model Context Protocol servers via SSE.
- **Voice Magic**: pulsing microphone UI for STT and volume controls for TTS on each bubble.
- **Performance Boost**: Forced GPU acceleration (32 layers default) and Metal/Vulkan optimization.
- **Desktop Excellence**: Adaptive chat layouts and native keyboard shortcuts (`Cmd+Enter`, `Cmd+K`).
- **Highest Max Testing**: Comprehensive integration test suite covering the full AI lifecycle.

### Changed
- **UI Rewrite**: Completely refactored `AgentChatView` with Markdown rendering and selective text support.
- **Core State**: Upgraded `FlutterLocalAgentKit` to handle session persistence with multimodal history.

### Fixed
- **OOM Protection**: Implemented chunked hashing for large model verification.
- **Lint Cleanup**: 100% clean `flutter analyze` score.
- **Async Safety**: Added `mounted` checks across all UI-to-Logic gaps.

---

## [1.0.0] - Initial Release
- Basic LLM inference support.
- Simple chat UI.
- Local storage for message history.
