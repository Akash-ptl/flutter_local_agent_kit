# Flutter Local Agent Kit 🤖✨

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-iOS%20%7C%20Android%20%7C%20macOS-blue?style=for-the-badge)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)

**A high-performance, local-first AI orchestration framework for Flutter.**  
Developed with a focus on privacy, low-latency, and cross-platform hardware acceleration.

---

## 📖 Overview

The **Flutter Local Agent Kit** enables developers to build state-of-the-art AI applications that run entirely on-device. By bypassing cloud APIs, you eliminate latency, protect user privacy, and remove per-token costs. It is engineered to leverage native GPU acceleration (Metal/Vulkan) and provide a seamless "Google-Expert" level developer experience.

### Why this package?

*   **🔒 Absolute Privacy**: No data ever leaves the device. Ideal for healthcare, finance, and enterprise apps.
*   **🏎️ Zero Latency**: Native bindings to GGUF and ONNX engines ensure immediate inference.
*   **🎮 Unified UI**: A complete, adaptive design system for chat, vision, and voice built with Flutter best practices.
*   **🛠️ Architecture-First**: Clean, modular code that separates inference, RAG, and UI layers.

---

## 🚀 Technical Highlights

### 👁️ Multimodal Vision Engine
Built-in support for `CLIP` and multimodal projectors. The kit automatically handles image resizing, normalization, and embedding to allow the LLM to "see" your UI or camera feed.

### 📚 Advanced Local RAG (Retrieval Augmented Generation)
Powered by an on-device vector database with:
- **Chunk-based retrieval** for precision.
- **Live Citation system**: Users see exactly which part of their PDF the answer came from.
- **Hybrid Search**: Combines semantic vector search with keyword-based BM25.

### 🔌 Model Context Protocol (MCP) Support
The first Flutter kit to implement the **Model Context Protocol**. Connect your local agent to thousands of external tools via SSE, enabling the agent to search the web, query databases, or control local files.

---

## 📊 Platform Support & Performance

| Platform | Acceleration | Min Version | Recommended Specs |
|----------|--------------|-------------|-------------------|
| **iOS**  | Metal (CoreML) | iOS 13.0+   | A12 Bionic or newer |
| **macOS**| Metal        | 10.15+      | Apple Silicon (M1+) |
| **Android**| Vulkan (NNAPI)| API 24+     | 8GB+ RAM          |

---

## 💻 Implementation

### 1. Initialization
Engineered for speed. We recommend initializing once at app startup:

```dart
final kit = FlutterLocalAgentKit();

await kit.initialize(
  modelPath: 'assets/models/mistral-7b.gguf',
  // Forced GPU offloading for maximum performance
  gpuLayers: 32, 
  contextSize: 4096,
);
```

### 2. Standardized Chat UI
The `AgentChatView` is built for modern UX, supporting Markdown, Code Highlighting, and Voice.

```dart
AgentChatView(
  onMessage: (content, {imageBytes, onCitations}) {
    return kit.askStream(
      content,
      imageBytes: imageBytes,
      onCitations: (results) {
        // Logic to render citations in the UI
        onCitations?.call(results);
      },
    );
  },
  theme: AgentChatTheme.premiumDark(),
)
```

---

## 🎹 Desktop Workflow
Boost productivity with native desktop enhancements:
- **Keyboard Shortcuts**: 
    - `Cmd/Ctrl + Enter`: Instantly send queries.
    - `Cmd/Ctrl + K`: Purge context and clear UI.
- **Adaptive Bubbles**: Constrained layouts for large monitors to prevent "Wall of Text" fatigue.

---

## 🧪 Testing Excellence
We maintain a **"Highest Possible Max"** testing standard.

```bash
# Run unit tests for core logic
flutter test

# Run the integration suite for full RAG + Vision validation
flutter test test/highest_max_test.dart
```

---

## 🤝 Contributing
We follow the **Google Flutter Style Guide**. Pull requests are welcome! Please ensure all tests pass and documentation is updated.

---

## 📜 License
Distributed under the MIT License. See `LICENSE` for more information.

---

<p align="center">
  Built with ❤️ for the Flutter Ecosystem.
</p>
