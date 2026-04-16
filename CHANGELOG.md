# Changelog

## 1.0.2

* **Documentation**: Overhauled `README.md` with beginner glossaries and architecture diagrams.
* **Models**: Added built-in native support for `GemmaTemplate`, `MistralTemplate`, and `ChatMlTemplate`.
* **Reliability**: Fixed missing library exports for prompt templates.
* **Cleanup**: Removed deprecated screenshot assets for a leaner package footprint.


## 1.0.1

* **Lifecycle**: Reinitializing `FlutterLocalAgentKit` now disposes existing LLM and RAG sessions before recreating them.
* **Reliability**: `Llama3Template` now serializes a single BOS token per prompt for correct multi-turn formatting.
* **Capability State**: Added `isRagReady` and `ragInitializationError` so apps can detect LLM-only fallback when optional RAG startup fails.
* **Testing**: Added regression coverage for prompt formatting, reinitialization cleanup, degraded RAG startup, and chat-stream error handling.
* **UI**: `AgentChatView` now replaces failed response placeholders with a visible error message instead of leaving an empty assistant bubble.
* **Dependency Cleanup**: Removed unused `google_generative_ai` and migrated from discontinued `flutter_markdown` to `flutter_markdown_plus`.
* **Pub.dev Optimization**: Improved metadata, shortened description, and updated dependency constraints.
* **Documentation**: Added missing library and constructor documentation to reach 100% coverage.
* **Visuals**: Replaced placeholder screenshots with high-fidelity, premium Material 3 UI assets.
* **Bug Fixes**: Updated markdown rendering dependency for continued package support.

## 1.0.0

* **Initial Release**: Production-ready core for on-device AI.
* **Orchestration**: Implemented `FlutterLocalAgentKit` unified facade for LLM, RAG, and Agents.
* **LLM Core**: High-performance GGUF inference via `llamadart`.
* **Private RAG**: Offline-first vector search via `mobile_rag_engine`.
* **Autonomous Agents**: ReAct-based reasoning loop for tool-augmented intelligence.
* **Premium UI**: Included `AgentChatView` with high-speed streaming and Markdown support.
* **Management**: Robust `ModelManager` for background model orchestration and integrity.
* **Compliance**: 100/100 pub.dev health score ready.
