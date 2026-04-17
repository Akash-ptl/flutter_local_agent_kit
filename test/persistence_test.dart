import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('persistence_test');
    // Note: In a real Flutter test, we'd mock path_provider.
    // Here we'll just test the logic if possible or rely on the mock.
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('AgentChatMessage JSON serialization', () {
    final message = AgentChatMessage.user('Hello world', id: '123');
    final json = message.toJson();
    
    expect(json['id'], '123');
    expect(json['content'], 'Hello world');
    expect(json['role'], 'user');
    
    final decoded = AgentChatMessage.fromJson(json);
    expect(decoded.id, message.id);
    expect(decoded.content, message.content);
    expect(decoded.role, message.role);
  });

  test('MessageRole serialization', () {
    expect(MessageRole.fromString('system'), MessageRole.system);
    expect(MessageRole.fromString('ASSISTANT'), MessageRole.assistant);
    expect(MessageRole.fromString('unknown'), MessageRole.user); // default
  });
}
