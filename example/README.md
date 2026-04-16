# 🎮 flutter_local_agent_kit Demo App

This full-fledged demo app showcases how to integrate the **Flutter Local Agent Kit** into a production environment. It provides a beautiful Material 3 chat interface that runs completely offline.

## 🌟 What This Demo Shows

- **Model Management**: Downloading and verifying a local GGUF model dynamically.
- **Initialization**: Booting up `FlutterLocalAgentKit` safely.
- **RAG Subsystem**: Injecting and retrieving local knowledge securely.
- **UI Integration**: Dropping the `AgentChatView` into a standard Flutter Scaffold structure.

## 🚀 How to Run

1. Make sure you have a physical mobile device connected or a capable Desktop simulator (iOS/Android/macOS). CPU inference works best on real hardware.
2. Run the following commands:

```bash
flutter pub get
flutter run
```

## 📂 Project Structure

- `lib/main.dart` - Entry point and UI scaffolding.
- `assets/ai/` - Contains the required RAG tokenizers and embedding models.

> **Note:** The app will attempt to automatically download a recommended lightweight Llama model (~1GB) on the first run. Make sure you have adequate storage space available on your device!
