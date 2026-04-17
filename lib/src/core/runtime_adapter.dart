import 'package:llamadart/llamadart.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/llm/prompt_templates.dart';
import 'package:flutter_local_agent_kit/src/rag/rag_service.dart';

/// Runtime abstraction for native engine setup and teardown.
abstract class KitRuntimeAdapter {
  /// Creates an initialized LLM session.
  Future<LlmRuntimeSession> initializeLlm({
    required String modelPath,
    required PromptTemplate template,
    required int contextSize,
    required int gpuLayers,
    bool useCoreML = false,
    bool useNnapi = false,
  });

  /// Creates an initialized RAG session.
  Future<RagRuntimeSession> initializeRag({
    String? storagePath,
    required String tokenizerAsset,
    required String modelAsset,
  });
}

/// Runtime-owned LLM resources.
class LlmRuntimeSession {
  /// Service exposed to the kit.
  final LlmService service;

  /// Cleanup callback for native resources.
  final Future<void> Function() dispose;

  /// Creates an [LlmRuntimeSession].
  LlmRuntimeSession({
    required this.service,
    required this.dispose,
  });
}

/// Runtime-owned RAG resources.
class RagRuntimeSession {
  /// Service exposed to the kit.
  final RagService service;

  /// Cleanup callback for native resources.
  final Future<void> Function() dispose;

  /// File ingestion callback for the underlying RAG engine.
  final Future<void> Function(String filePath) ingestFile;

  /// Creates a [RagRuntimeSession].
  RagRuntimeSession({
    required this.service,
    required this.dispose,
    required this.ingestFile,
  });
}

/// Default adapter backed by the production native engines.
class DefaultKitRuntimeAdapter implements KitRuntimeAdapter {
  @override
  Future<LlmRuntimeSession> initializeLlm({
    required String modelPath,
    required PromptTemplate template,
    required int contextSize,
    required int gpuLayers,
    bool useCoreML = false,
    bool useNnapi = false,
  }) async {
    final engine = LlamaEngine(LlamaBackend());
    await engine.loadModel(
      modelPath,
      modelParams: ModelParams(
        contextSize: contextSize,
        gpuLayers: gpuLayers,
        // TODO: Enable these when llamadart supports them directly
        // useCoreML: useCoreML,
        // useNnapi: useNnapi,
      ),
    );

    return LlmRuntimeSession(
      service: LlmService(engine: engine, template: template),
      dispose: engine.dispose,
    );
  }

  @override

  /// Creates the production `mobile_rag_engine` session and its file-ingestion hook.
  Future<RagRuntimeSession> initializeRag({
    String? storagePath,
    required String tokenizerAsset,
    required String modelAsset,
  }) async {
    await MobileRag.initialize(
      tokenizerAsset: tokenizerAsset,
      modelAsset: modelAsset,
      databaseName: storagePath ?? 'agent_kit.sqlite',
    );

    final rag = MobileRag.instance;

    final service = RagService(rag);

    return RagRuntimeSession(
      service: service,
      ingestFile: (filePath) => service.addFile(filePath),
      dispose: MobileRag.dispose,
    );
  }
}
