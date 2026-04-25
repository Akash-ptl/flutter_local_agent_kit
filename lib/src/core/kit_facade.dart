import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/llm/prompt_templates.dart';
import 'package:flutter_local_agent_kit/src/rag/rag_service.dart';
import 'package:flutter_local_agent_kit/src/agent/agent_service.dart';
import 'package:flutter_local_agent_kit/src/agent/tools.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:flutter_local_agent_kit/src/core/persistence.dart';
import 'package:flutter_local_agent_kit/src/core/runtime_adapter.dart';
import 'package:flutter_local_agent_kit/src/utils/model_manager.dart';
import 'package:flutter_local_agent_kit/src/agent/mcp_service.dart';
import 'package:mcp_dart/mcp_dart.dart' show Transport;

/// Status of the [FlutterLocalAgentKit] as it initializes and operates.
enum KitStatus {
  /// Kit is created but no models are loaded.
  uninitialized,

  /// Currently loading models and initializing native engines.
  initializing,

  /// Models are loaded and services are ready to process queries.
  ready,

  /// An error occurred during initialization.
  error,
}

/// The Flutter Local Agent Kit is the central entry point for on-device AI.
///
/// It orchestrates LLM inference, RAG knowledge retrieval, and autonomous agents.
class FlutterLocalAgentKit {
  /// Creates the main entry point for local model inference, tools, and RAG.
  ///
  /// Provide a custom [runtimeAdapter] to override how native LLM and RAG
  /// sessions are created, which is especially useful in tests or custom
  /// embeddings/runtime integrations.
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
  final PersistenceService _persistence = PersistenceService();
  final McpService _mcpService = McpService();
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

  /// The [PersistenceService] responsible for saving and loading chat sessions.
  PersistenceService get persistence => _persistence;

  /// Returns whether the optional RAG subsystem is available.
  bool get isRagReady => _ragService != null;

  /// The most recent RAG initialization error, if startup fell back to LLM-only mode.
  Object? get ragInitializationError => _ragInitializationError;

  /// The total context window (max tokens) currently available to the LLM.
  int get contextSize => _llmService?.contextSize ?? 0;

  /// Boots all AI services (LLM and RAG) in a single call.
  ///
  /// [modelPath] is the absolute path to the GGUF model file.
  /// [template] defines the prompt format (defaults to Llama 3).
  /// [ragDatabasePath] overrides the on-device database file used by the
  /// optional RAG subsystem.
  /// [tokenizerAsset] and [modelAsset] configure the RAG embedding assets.
  /// [customTools] replaces the default calculator and time tools exposed to
  /// the built-in agent loop.
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
    String? projectorPath,
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
        projectorPath: projectorPath,
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
  ///
  /// This is useful when consumers need manual control over the LLM lifecycle
  /// and do not want to boot the optional RAG subsystem.
  Future<void> initializeLlm({
    required String modelPath,
    required PromptTemplate template,
    int contextSize = 4096,
    int gpuLayers = 32,
    String? projectorPath,
  }) async {
    _llmSession = await _runtimeAdapter.initializeLlm(
      modelPath: modelPath,
      template: template,
      contextSize: contextSize,
      gpuLayers: gpuLayers,
      multimodalProjectorPath: projectorPath,
    );
    _llmService = _llmSession!.service;
  }

  /// Individually initializes the RAG engine for knowledge management.
  ///
  /// [storagePath] overrides the database file name used by the local vector
  /// store, while [tokenizerAsset] and [modelAsset] point to the embedding
  /// assets required by `mobile_rag_engine`.
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

  /// Connects to a remote MCP server to expand the agent's tool capabilities.
  ///
  /// This automatically discovers tools on the server and injects them into
  /// the active [AgentService].
  Future<void> useMcpServer(Transport transport) async {
    await _mcpService.connect(transport);
    if (_agentService != null) {
      final mcpTools = await _mcpService.getTools();
      // Update agent with combined toolset
      _agentService = AgentService(
        _llmService!,
        [..._agentService!.tools, ...mcpTools],
      );
    }
  }

  /// Saves the current conversation history to local storage.
  Future<void> saveSession(
      String sessionId, List<AgentChatMessage> history) async {
    await _persistence.saveSession(sessionId, history);
  }

  /// Loads a previous conversation history from local storage.
  Future<List<AgentChatMessage>> loadSession(String sessionId) async {
    return _persistence.loadSession(sessionId);
  }

  void _updateStatus(KitStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  Future<void> _disposeResources() async {
    await _llmSession?.dispose();
    await _ragSession?.dispose();
    await _mcpService.dispose();
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
  /// [maxTokens] limits the length of each generation turn.
  Stream<String> runAgent(String query, {String? systemPrompt, int? maxTokens}) {
    if (!isReady) throw Exception('Kit is not ready');

    // Create a temporary service instance if a custom prompt is provided
    final service = systemPrompt != null
        ? AgentService(_llmService!, _agentService!.tools,
            customInstructions: systemPrompt)
        : _agentService!;

    return service.run(query, maxTokens: maxTokens);
  }

  /// Performs a high-speed RAG-augmented query against the local knowledge base.
  ///
  /// Pass prior conversation [history] to preserve context across turns.
  /// [imageBytes] allows providing an image for multimodal analysis.
  /// [onCitations] is called when RAG results are retrieved, before streaming starts.
  /// [maxTokens] limits the response length.
  Stream<String> askStream(
    String query, {
    List<AgentChatMessage> history = const [],
    List<int>? imageBytes,
    void Function(List<RetrievalResult> citations)? onCitations,
    int? maxTokens,
  }) async* {
    if (!isReady) throw Exception('Kit is not ready');

    // Retrieve structured results
    final results = _ragService != null
        ? await _ragService!.retrieve(query)
        : <RetrievalResult>[];

    // Inform caller about retrieved citations
    if (onCitations != null && results.isNotEmpty) {
      onCitations(results);
    }

    final context = results.map((r) => r.content).toList();

    final messages = [
      if (context.isNotEmpty)
        AgentChatMessage.system('Context:\n${context.join('\n')}'),
      ...history,
      AgentChatMessage(
        id: const Uuid().v4(),
        content: query,
        role: MessageRole.user,
        timestamp: DateTime.now(),
        imageBytes: imageBytes,
      ),
    ];

    yield* _llmService!.generateChatStream(messages, maxTokens: maxTokens);
  }

  /// Closes all native engines and releases all held RAM.
  Future<void> dispose() async {
    await _disposeResources();
    await _statusController.close();
  }
}
