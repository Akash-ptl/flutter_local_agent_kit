import 'dart:async';
import 'package:llamadart/llamadart.dart';
import 'package:mobile_rag_engine/mobile_rag_engine.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/llm/prompt_templates.dart';
import 'package:flutter_local_agent_kit/src/rag/rag_service.dart';
import 'package:flutter_local_agent_kit/src/agent/agent_service.dart';
import 'package:flutter_local_agent_kit/src/agent/tools.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:flutter_local_agent_kit/src/utils/model_manager.dart';


/// {@template flutter_local_agent_kit}
/// The Flutter Local Agent Kit is the central entry point for on-device AI.
/// 
/// It orchestrates LLM inference, RAG knowledge retrieval, and autonomous agents.
/// {@endtemplate}
class FlutterLocalAgentKit {
  /// Internal constructor for [FlutterLocalAgentKit].
  FlutterLocalAgentKit();

  LlamaEngine? _llmEngine;
  MobileRag? _ragEngine;
  
  LlmService? _llmService;
  RagService? _ragService;
  AgentService? _agentService;
  final ModelManager _modelManager = ModelManager();

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
    _updateStatus(KitStatus.initializing);

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
        // RAG is skipped if assets are missing or incompatible, but LLM remains operational.
        // In a production app, you might log this to a crash reporting service.
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
    _llmEngine = LlamaEngine(LlamaBackend()); 
    await _llmEngine!.loadModel(
      modelPath,
      modelParams: ModelParams(
        contextSize: contextSize,
        gpuLayers: gpuLayers,
      ),
    );
    _llmService = LlmService(engine: _llmEngine!, template: template);
  }

  /// Individually initializes the RAG engine for knowledge management.
  Future<void> initializeRag({
    String? storagePath,
    String tokenizerAsset = 'assets/ai/tokenizer.json',
    String modelAsset = 'assets/ai/embeddings.onnx',
  }) async {
    await MobileRag.initialize(
      tokenizerAsset: tokenizerAsset,
      modelAsset: modelAsset,
      databaseName: storagePath ?? 'agent_kit.sqlite',
    );
    _ragEngine = MobileRag.instance;
    _ragService = RagService(_ragEngine!);
  }

  /// Ingests a local file into the RAG engine.
  Future<void> ingestFile(String filePath) async {
    if (_ragEngine == null) throw Exception('RAG engine not initialized');
    await _ragEngine!.addDocumentFromFile(
      filePath,
      metadata: 'Source: Local File',
    );
  }

  void _updateStatus(KitStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
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
    await _llmEngine?.dispose();
    await MobileRag.dispose(); 
    await _statusController.close();
    _llmEngine = null;
    _ragEngine = null;
    _status = KitStatus.uninitialized;
  }
}
