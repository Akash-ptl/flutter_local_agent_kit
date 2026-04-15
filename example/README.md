# flutter_local_agent_kit Example

This example shows how to:

- download or reuse a local GGUF model
- initialize `FlutterLocalAgentKit`
- render the built-in `AgentChatView`
- surface a simple offline-first local agent experience

## Run the example

```bash
flutter pub get
flutter run
```

The example app expects local RAG assets from `example/assets/ai/` and will
download the recommended demo model if it is not already available on the
device.
