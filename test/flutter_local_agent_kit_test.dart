import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/rag/rag_service.dart';
import 'package:llamadart/llamadart.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';

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
      expect(kit.isRagReady, false);
      expect(kit.ragInitializationError, isNull);
    });

    test('reinitialize disposes previous sessions before creating new ones',
        () async {
      final runtime = _FakeKitRuntimeAdapter();
      final kit = FlutterLocalAgentKit(runtimeAdapter: runtime);

      await kit.initialize(modelPath: 'model-a.gguf');
      expect(kit.isReady, true);
      expect(runtime.llmInitializeCount, 1);
      expect(runtime.llmDisposeCount, 0);
      expect(runtime.ragDisposeCount, 0);

      await kit.initialize(modelPath: 'model-b.gguf');

      expect(kit.isReady, true);
      expect(runtime.llmInitializeCount, 2);
      expect(runtime.llmDisposeCount, 1);
      expect(runtime.ragDisposeCount, 1);
    });

    test(
        'RAG init failure preserves ready state but exposes degraded capability',
        () async {
      final runtime = _FakeKitRuntimeAdapter(
        ragInitializationError: StateError('missing rag assets'),
      );
      final kit = FlutterLocalAgentKit(runtimeAdapter: runtime);

      await kit.initialize(modelPath: 'model.gguf');

      expect(kit.status, KitStatus.ready);
      expect(kit.isReady, true);
      expect(kit.isRagReady, false);
      expect(kit.ragInitializationError, isA<StateError>());
    });
  });

  group('Prompt Template Test', () {
    test('Llama3Template should emit BOS only once per prompt', () {
      final template = Llama3Template();
      final prompt = template.formatMessages([
        AgentChatMessage.system('System instructions'),
        AgentChatMessage.user('Hello'),
        AgentChatMessage.assistant('Hi'),
      ]);

      expect('<|begin_of_text|>'.allMatches(prompt), hasLength(1));
      expect(
        prompt,
        startsWith(
          '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n'
          'System instructions<|eot_id|>',
        ),
      );
      expect(
        prompt,
        contains(
          '<|start_header_id|>user<|end_header_id|>\n\nHello<|eot_id|>',
        ),
      );
      expect(
        prompt,
        endsWith('<|start_header_id|>assistant<|end_header_id|>\n\n'),
      );
    });
  });
}

class _FakeKitRuntimeAdapter implements KitRuntimeAdapter {
  _FakeKitRuntimeAdapter({
    this.ragInitializationError,
  });

  final Object? ragInitializationError;
  int llmInitializeCount = 0;
  int llmDisposeCount = 0;
  int ragDisposeCount = 0;

  @override
  Future<LlmRuntimeSession> initializeLlm({
    required String modelPath,
    required PromptTemplate template,
    required int contextSize,
    required int gpuLayers,
    bool useCoreML = false,
    bool useNnapi = false,
  }) async {
    llmInitializeCount++;

    return LlmRuntimeSession(
      service: LlmService(
        engine: _FakeLlamaEngine(),
        template: template,
      ),
      dispose: () async {
        llmDisposeCount++;
      },
    );
  }

  @override
  Future<RagRuntimeSession> initializeRag({
    String? storagePath,
    required String tokenizerAsset,
    required String modelAsset,
  }) async {
    if (ragInitializationError != null) {
      throw ragInitializationError!;
    }

    return RagRuntimeSession(
      service: RagService(_FakeMobileRag()),
      ingestFile: (_) async {},
      dispose: () async {
        ragDisposeCount++;
      },
    );
  }
}

class _FakeLlamaEngine implements LlamaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMobileRag implements MobileRag {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
