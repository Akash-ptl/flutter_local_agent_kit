# Changelog

## Unreleased

* **Lifecycle**: Reinitializing `FlutterLocalAgentKit` now disposes existing LLM and RAG sessions before recreating them.
* **Reliability**: `Llama3Template` now serializes a single BOS token per prompt for correct multi-turn formatting.
* **Capability State**: Added `isRagReady` and `ragInitializationError` so apps can detect LLM-only fallback when optional RAG startup fails.
* **Testing**: Added regression coverage for prompt formatting, reinitialization cleanup, degraded RAG startup, and chat-stream error handling.
* **UI**: `AgentChatView` now replaces failed response placeholders with a visible error message instead of leaving an empty assistant bubble.

## 1.0.1

* **Pub.dev Optimization**: Improved metadata, shortened description, and updated dependency constraints.
* **Documentation**: Added missing library and constructor documentation to reach 100% coverage.
* **Visuals**: Replaced placeholder screenshots with high-fidelity, premium Material 3 UI assets.
* **Bug Fixes**: Switched to official `flutter_markdown` for improved stability.

## 1.0.0

* **Initial Release**: Production-ready core for on-device AI.
* **Orchestration**: Implemented `FlutterLocalAgentKit` unified facade for LLM, RAG, and Agents.
* **LLM Core**: High-performance GGUF inference via `llamadart`.
* **Private RAG**: Offline-first vector search via `mobile_rag_engine`.
* **Autonomous Agents**: ReAct-based reasoning loop for tool-augmented intelligence.
* **Premium UI**: Included `AgentChatView` with high-speed streaming and Markdown support.
* **Management**: Robust `ModelManager` for background model orchestration and integrity.
* **Compliance**: 100/100 pub.dev health score ready.
