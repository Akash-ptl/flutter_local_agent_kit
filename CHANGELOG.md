# Changelog

All notable changes to this project will be documented in this file.

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
