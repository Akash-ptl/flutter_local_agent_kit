import 'dart:async';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/llm/prompt_templates.dart';
import 'package:flutter_local_agent_kit/src/rag/rag_service.dart';
import 'package:flutter_local_agent_kit/src/agent/agent_service.dart';
import 'package:flutter_local_agent_kit/src/agent/tools.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:flutter_local_agent_kit/src/core/runtime_adapter.dart';
import 'package:flutter_local_agent_kit/src/utils/model_manager.dart';


/// {@template flutter_local_agent_kit}
/// The Flutter Local Agent Kit is the central entry point for on-device AI.
/// 
/// It orchestrates LLM inference, RAG knowledge retrieval, and autonomous agents.
/// {@endtemplate}
class FlutterLocalAgentKit {
  /// Internal constructor for [FlutterLocalAgentKit].
  FlutterLocalAgentKit({
    KitRuntimeAdapter? runtimeAdapter,
  }) : _runtimeAdapter = runtimeAdapter ?? DefaultKitRuntimeAdapter();

  final KitRuntimeAdapter _runtimeAdapter;
  LlmRuntimeSession? _llmSession;
  RagRuntimeSession? _ragSession;
  LlmService? _llmService;
  RagService? _ragService;
  AgentService? _agentService;
  final ModelManager _modelManager = ModelManager();
  Object? _ragInitializationError;

  final _statusController = StreamController<KitStatus>.broadcast();
  KitStatus _status = KitStatus.uninitialized;

  /// A stream that emits the current [KitStatus] as the engine boots.
  Stream<KitStatus> get statusStream => _statusController.stream;
  
  /// The current state of the kit (uninitialized, ready, error, etc.)
  KitStatus get status => _status;

  /// Returns true if the kit is fully initialized and ready to process queries.
  bool get isReady => _status == KitStatus.ready;

  /// The [RagService] responsible for local document indexing and retrieval.
  RagService? get rag => _ragService;

  /// The [ModelManager] responsible for background model downloads and integrity checks.
  ModelManager get models => _modelManager;

  /// Returns whether the optional RAG subsystem is available.
  bool get isRagReady => _ragService != null;

  /// The most recent RAG initialization error, if startup fell back to LLM-only mode.
  Object? get ragInitializationError => _ragInitializationError;

  /// Boots all AI services (LLM and RAG) in a single call.
  /// 
  /// [modelPath] is the absolute path to the GGUF model file.
  /// [template] defines the prompt format (defaults to Llama 3).
  /// [contextSize] determines the LLM memory window (defaults to 4096).
  /// [gpuLayers] determines the number of layers offloaded to the GPU (defaults to 32).
  Future<void> initialize({
    required String modelPath,
    PromptTemplate? template,
    String? ragDatabasePath,
    String tokenizerAsset = 'assets/ai/tokenizer.json',
    String modelAsset = 'assets/ai/embeddings.onnx',
    List<BaseTool>? customTools,
    int contextSize = 4096,
    int gpuLayers = 32,
  }) async {
    if (_status == KitStatus.initializing) return;

    if (_status != KitStatus.uninitialized) {
      await _disposeResources();
    }

    _updateStatus(KitStatus.initializing);
    _ragInitializationError = null;

    try {
      // 1. Initialize LLM (Critical Core)
      await initializeLlm(
        modelPath: modelPath, 
        template: template ?? Llama3Template(),
        contextSize: contextSize,
        gpuLayers: gpuLayers,
      );
      
      // 2. Attempt RAG Initialization (Optional Enhancement)
      try {
        await initializeRag(
          storagePath: ragDatabasePath,
          tokenizerAsset: tokenizerAsset,
          modelAsset: modelAsset,
        );
      } catch (e) {
        // RAG is optional, but callers should be able to detect when startup fell back
        // to LLM-only mode and decide whether to disable knowledge features.
        _ragInitializationError = e;
      }
      
      // 3. Setup Agent with LLM (Always possible once LLM service is up)
      _agentService = AgentService(
        _llmService!, 
        customTools ?? [CalculatorTool(), DateTimeTool()],
      );

      _updateStatus(KitStatus.ready);
    } catch (e) {
      _updateStatus(KitStatus.error);
      rethrow;
    }
  }


  /// Individually initializes the LLM engine for light-weight chat scenarios.
  Future<void> initializeLlm({
    required String modelPath,
    required PromptTemplate template,
    int contextSize = 4096,
    int gpuLayers = 32,
  }) async {
    _llmSession = await _runtimeAdapter.initializeLlm(
      modelPath: modelPath,
      template: template,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
    );
    _llmService = _llmSession!.service;
  }

  /// Individually initializes the RAG engine for knowledge management.
  Future<void> initializeRag({
    String? storagePath,
    String tokenizerAsset = 'assets/ai/tokenizer.json',
    String modelAsset = 'assets/ai/embeddings.onnx',
  }) async {
    _ragSession = await _runtimeAdapter.initializeRag(
      storagePath: storagePath,
      tokenizerAsset: tokenizerAsset,
      modelAsset: modelAsset,
    );
    _ragService = _ragSession!.service;
  }

  /// Ingests a local file into the RAG engine.
  Future<void> ingestFile(String filePath) async {
    if (_ragSession == null) throw Exception('RAG engine not initialized');
    await _ragSession!.ingestFile(filePath);
  }

  void _updateStatus(KitStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<void> _disposeResources() async {
    await _llmSession?.dispose();
    await _ragSession?.dispose();
    _llmSession = null;
    _ragSession = null;
    _llmService = null;
    _ragService = null;
    _agentService = null;
    _ragInitializationError = null;
    _status = KitStatus.uninitialized;
  }

  /// Executes an autonomous reasoning loop.
  /// 
  /// [systemPrompt] allows overriding the default agent instructions.
  Stream<String> runAgent(String query, {String? systemPrompt}) {
    if (!isReady) throw Exception('Kit is not ready');
    
    // Create a temporary service instance if a custom prompt is provided
    final service = systemPrompt != null 
        ? AgentService(_llmService!, _agentService!.tools, customInstructions: systemPrompt)
        : _agentService!;
        
    return service.run(query);
  }


  /// Performs a high-speed RAG-augmented query against the local knowledge base.
  Stream<String> askStream(String query, {List<AgentChatMessage> history = const []}) async* {
    if (!isReady) throw Exception('Kit is not ready');
    
    // Attempt to retrieve context only if RAG is available.
    final context = _ragService != null 
        ? await _ragService!.retrieveContext(query)
        : <String>[];
        
    final messages = [
      if (context.isNotEmpty)
        AgentChatMessage.system('Context:\n${context.join('\n')}'),
      ...history,
      AgentChatMessage.user(query),
    ];
    yield* _llmService!.generateStream(_llmService!.format(messages));
  }

  /// Closes all native engines and releases all held RAM.
  Future<void> dispose() async {
    await _disposeResources();
    await _statusController.close();
  }
}
