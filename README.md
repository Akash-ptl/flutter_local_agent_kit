# Flutter Local Agent Kit 🤖✨

[![pub package](https://img.shields.io/pub/v/flutter_local_agent_kit.svg)](https://pub.dev/packages/flutter_local_agent_kit)
[![Flutter Favorite](https://img.shields.io/badge/Flutter-Favorite-6750A4)](https://flutter.dev/docs/development/packages-and-plugins/favorites)

The ultimate **offline-first** AI framework for Flutter. Build autonomous agents, private RAG systems, and high-performance chat interfaces that run 100% on-device.

---

## 🌟 Key Features

*   **🧠 High-Performance Inference**: Native integration with `llamadart` supporting Llama 3.2, Gemma, and Mistral.
*   **🕵️ Autonomous Agents**: Built-in ReAct (Reason-Act) loop for tool use (Calculators, APIs, System tasks).
*   **📚 Private RAG**: local vector database for knowledge injection without cloud dependencies.
*   **🎨 Premium UI Components**: 120Hz smooth `AgentChatView` with Markdown, code blocks, and **Suggestion Chips**.
*   **🛡️ Secure & Private**: No API keys, no data leaves the device. Perfect for privacy-first enterprise apps.
*   **⚙️ Customizable Personas**: Easily set custom system prompts for specialized agent behaviors.

---

## 🚀 Quick Start

### 1. Initialize the Kit
```dart
final kit = FlutterLocalAgentKit();

await kit.initialize(
  modelPath: '/path/to/llama-3.2-1b.gguf',
);
```

### 1a. Detect LLM-Only Fallback
```dart
await kit.initialize(modelPath: '/path/to/llama-3.2-1b.gguf');

if (!kit.isRagReady) {
  debugPrint('RAG unavailable: ${kit.ragInitializationError}');
}
```

The kit can still become `ready` when the optional RAG subsystem fails to boot.
Use `isRagReady` and `ragInitializationError` to disable knowledge features or
surface a degraded-mode message in your app.

### 2. Run an Autonomous Agent
```dart
kit.runAgent("Calculate my tax for 50k salary and tell me the time.").listen((chunk) {
  print(chunk); // Streams "Thought -> Action -> Observation -> Final Answer"
});
```

### 3. Use the Premium UI
```dart
AgentChatView(
  onMessage: (query) => kit.runAgent(query),
  suggestions: const ['🕵️ Who are you?', '📅 Get Time', '🧮 Solve math'],
  welcomeMessage: "Hello! I am your local AI agent.",
)
```

### 4. Inject a Custom Runtime Adapter
```dart
final kit = FlutterLocalAgentKit(
  runtimeAdapter: MyKitRuntimeAdapter(),
);
```

`KitRuntimeAdapter` lets you swap how LLM and RAG sessions are created. This is
useful for testing, custom native integrations, or controlling engine lifecycle
outside the default adapter.

---

## 🛠️ Built-in Tools
*   **Calculator**: High-precision math execution.
*   **DateTime**: Real-time context awareness.
*   **Custom Tools**: Easily extend with `BaseTool`.

---

## 📱 Performance (OnePlus 12)
*   **Model**: Llama 3.2 1B (Instruct)
*   **RAM Usage**: ~900MB (Stable)
*   **Throughput**: 45+ tokens/sec
*   **Latency**: <100ms first-token (Native Vulkan/Impeller)

---

## 📄 License
MIT License. Built with ❤️ for the Flutter Ecosystem (2026).
