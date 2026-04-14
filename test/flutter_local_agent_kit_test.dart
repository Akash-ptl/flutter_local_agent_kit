import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';

void main() {
  group('Models Test', () {
    test('AgentChatMessage should create valid user message', () {
      final msg = AgentChatMessage.user('Hello');
      expect(msg.content, 'Hello');
      expect(msg.role, MessageRole.user);
    });

    test('AgentChatMessage should create valid assistant message', () {
      final msg = AgentChatMessage.assistant('Hi there');
      expect(msg.content, 'Hi there');
      expect(msg.role, MessageRole.assistant);
    });
  });

  group('Facade State Test', () {
    test('Kit should start in uninitialized state', () {
      final kit = FlutterLocalAgentKit();
      expect(kit.status, KitStatus.uninitialized);
      expect(kit.isReady, false);
    });
  });
}
