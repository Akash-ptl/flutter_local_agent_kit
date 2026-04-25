import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/rag/rag_service.dart';
import 'package:llamadart/llamadart.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';

import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Highest Possible Max Integration Test', () {
    late FlutterLocalAgentKit kit;
    late _MockRuntimeAdapter mockRuntime;

    setUpAll(() {
      const MethodChannel('plugins.flutter.io/path_provider')
          .setMockMethodCallHandler((MethodCall methodCall) async {
        return '.';
      });
    });

    setUp(() {
      mockRuntime = _MockRuntimeAdapter();
      kit = FlutterLocalAgentKit(runtimeAdapter: mockRuntime);
    });

    test('Full Multimodal RAG turn with Citations and Streaming', () async {
      // 1. Initialize
      await kit.initialize(modelPath: 'test_model.gguf');
      expect(kit.isReady, isTrue);

      // 2. Ingest Document
      await kit.ingestFile('knowledge.pdf');

      // 3. Perform a Multimodal RAG Query
      final tokens = <String>[];
      final citations = <RetrievalResult>[];
      final imageBytes = [0xFF, 0xD8, 0xFF]; // Mock JPEG header

      final stream = kit.askStream(
        'What is in this image based on the PDF?',
        imageBytes: imageBytes,
        onCitations: (results) => citations.addAll(results),
      );

      await for (final token in stream) {
        tokens.add(token);
      }

      // 4. Assertions
      expect(citations, isNotEmpty, reason: 'Citations should be retrieved before streaming');
      expect(citations.first.content, contains('PDF Context'));
      expect(tokens.join(), contains('Mock AI Response'), reason: 'Should stream model output');
      
      // Verify the prompt sent to the model included context and vision data
      final lastPrompt = mockRuntime.lastPrompt;
      expect(lastPrompt, contains('Context:'), reason: 'RAG context should be in prompt');
      expect(mockRuntime.lastImageBytes, equals(imageBytes), reason: 'Vision data should be passed to engine');
    });

    test('Concurrency: Multiple overlapping queries should handle state safely', () async {
      await kit.initialize(modelPath: 'test_model.gguf');
      
      final future1 = kit.askStream('Query 1').toList();
      final future2 = kit.askStream('Query 2').toList();

      final results = await Future.wait([future1, future2]);
      
      expect(results[0].join(), contains('Mock AI Response'));
      expect(results[1].join(), contains('Mock AI Response'));
    });

    test('Persistence: Session saving and loading integrity', () async {
      await kit.initialize(modelPath: 'test_model.gguf');
      
      final history = [
        AgentChatMessage.user('Hi'),
        AgentChatMessage.assistant('Hello', metadata: {'test': true}),
      ];
      
      await kit.saveSession('test_sid', history);
      final loaded = await kit.loadSession('test_sid');
      
      expect(loaded.length, history.length);
      expect(loaded.last.metadata?['test'], isTrue);
    });
  });
}

class _MockRuntimeAdapter implements KitRuntimeAdapter {
  String? lastPrompt;
  List<int>? lastImageBytes;

  @override
  Future<LlmRuntimeSession> initializeLlm({
    required String modelPath,
    required PromptTemplate template,
    required int contextSize,
    required int gpuLayers,
    String? multimodalProjectorPath,
  }) async {
    return LlmRuntimeSession(
      service: _MockLlmService(
        template: template,
        contextSize: contextSize,
        onGenerate: (p, img) {
          lastPrompt = p;
          lastImageBytes = img;
        },
      ),
      dispose: () async {},
    );
  }

  @override
  Future<RagRuntimeSession> initializeRag({
    String? storagePath,
    required String tokenizerAsset,
    required String modelAsset,
  }) async {
    return RagRuntimeSession(
      service: RagService(_MockMobileRag()),
      ingestFile: (_) async {},
      dispose: () async {},
    );
  }
}

class _MockLlmService extends LlmService {
  final Function(String, List<int>?) onGenerate;

  _MockLlmService({
    required super.template,
    required super.contextSize,
    required this.onGenerate,
  }) : super(engine: _FakeLlamaEngine());

  @override
  Stream<String> generateChatStream(
    List<AgentChatMessage> messages, {
    double temperature = 0.7,
    int? maxTokens,
  }) async* {
    onGenerate(template.formatMessages(messages), 
              messages.where((m) => m.hasImage).firstOrNull?.imageBytes);
    yield 'Mock ';
    yield 'AI ';
    yield 'Response';
  }
}

class _FakeLlamaEngine implements LlamaEngine {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMobileRag implements MobileRag {
  @override
  Future<RagSearchResult> search(String query,
      {int topK = 5,
      int tokenBudget = 1000,
      ContextStrategy strategy = ContextStrategy.relevanceFirst,
      int adjacentChunks = 0,
      bool singleSourceMode = false,
      List<int>? sourceIds}) async {
    return RagSearchResult(
      context: AssembledContext(
        text: 'PDF Context for $query',
        estimatedTokens: 10,
        remainingBudget: 990,
        includedChunks: [],
      ),
      chunks: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
