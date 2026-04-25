import 'package:flutter/material.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mcp_dart/mcp_dart.dart' as mcp;

void main() {
  runApp(const LocalAgentStudio());
}

/// A premium, production-grade demo app for Flutter Local Agent Kit.
class LocalAgentStudio extends StatelessWidget {
  const LocalAgentStudio({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Agent Studio',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blueAccent,
        fontFamily: 'Inter',
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      ),
      home: const AgentStudioPage(),
    );
  }
}

class AgentStudioPage extends StatefulWidget {
  const AgentStudioPage({super.key});

  @override
  State<AgentStudioPage> createState() => _AgentStudioPageState();
}

class _AgentStudioPageState extends State<AgentStudioPage> {
  final FlutterLocalAgentKit _kit = FlutterLocalAgentKit();

  bool _isInitializing = true;
  String _loadingMessage = 'Starting Engines...';
  double _downloadProgress = 0.0;

  List<AgentChatMessage> _currentHistory = [];
  String _activeSessionId = 'default_session';
  List<String> _allSessions = [];

  @override
  void initState() {
    super.initState();
    _initializeKit();
  }

  Future<void> _initializeKit() async {
    setState(() {
      _isInitializing = true;
      _loadingMessage = 'Locating Model Weights...';
    });

    try {
      final modelDef = ModelManager.recommendedModels.first;
      final isDownloaded = await _kit.models.isModelDownloaded(modelDef.id);
      final modelPath = await _kit.models.getLocalPath(modelDef.id);

      if (!isDownloaded) {
        setState(() => _loadingMessage = 'Downloading ${modelDef.name}...');
        await _kit.models.downloadModel(
          modelDef,
          onProgress: (p) => setState(() => _downloadProgress = p),
        );
      }

      setState(() => _loadingMessage = 'Initializing Neural Runtime...');
      await _kit.initialize(
        modelPath: modelPath,
        gpuLayers: 32, // Max efficiency offloading
      );

      // Load sessions
      final sessions = await _kit.persistence.listSessions();
      final history = await _kit.loadSession(_activeSessionId);

      setState(() {
        _isInitializing = false;
        _allSessions = sessions.isEmpty ? [_activeSessionId] : sessions;
        _currentHistory = history;
      });
    } catch (e) {
      setState(() => _loadingMessage = 'Initialization Error: $e');
    }
  }

  Future<void> _switchSession(String id) async {
    final history = await _kit.loadSession(id);
    setState(() {
      _activeSessionId = id;
      _currentHistory = history;
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _createNewSession() async {
    final id = 'session_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _activeSessionId = id;
      _currentHistory = [];
      _allSessions.insert(0, id);
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleRealIngestion() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'json', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      if (!mounted) return;
      final path = result.files.single.path!;
      Navigator.pop(context);
      
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Ingesting ${result.files.single.name}...')),
      );

      try {
        await _kit.ingestFile(path);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Knowledge Base Updated Successfully.'),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ingestion Failed: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _connectMcp() async {
    final controller = TextEditingController(text: 'http://localhost:3001/sse');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to MCP Server'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Server SSE URL',
            hintText: 'http://localhost:3001/sse',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Connect')),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        final transport = mcp.StreamableHttpClientTransport(Uri.parse(controller.text));
        await _kit.useMcpServer(transport);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to MCP Server. Tools synchronized.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('MCP Connection Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return _buildLoadingScreen();

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Column(
          children: [
            Text('Local Agent Studio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Premium AI Experience',
                style: TextStyle(fontSize: 10, color: Colors.blueAccent)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lan_outlined),
            onPressed: _connectMcp,
            tooltip: 'Connect MCP Server',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion_rounded, size: 20),
            onPressed: _showKnowledgeBaseInfo,
            tooltip: 'Knowledge Base',
          ),
        ],
      ),
      body: AgentChatView(
        title: 'Neural Assistant',
        onMessage: (query, {imageBytes, onCitations}) => _kit.askStream(
          query,
          history: _currentHistory,
          imageBytes: imageBytes,
          onCitations: onCitations,
        ),
        initialHistory: _currentHistory,
        onHistoryChanged: (history) {
          _currentHistory = history;
          _kit.saveSession(_activeSessionId, history);
        },
        suggestions: const [
          '🕵️ Who are you?',
          '🖼️ Analyze this image',
          '📚 Check my Knowledge Base',
          '🛠️ List available tools',
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blueAccent),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.smart_toy_rounded, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text('Local Agent Studio',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_comment_rounded, color: Colors.blueAccent),
            title: const Text('New Chat', style: TextStyle(fontWeight: FontWeight.bold)),
            onTap: _createNewSession,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: _allSessions.length,
              itemBuilder: (context, index) {
                final id = _allSessions[index];
                final isActive = id == _activeSessionId;
                return ListTile(
                  selected: isActive,
                  leading: Icon(isActive ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded),
                  title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _switchSession(id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final isError = _loadingMessage.contains('Error');
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isError) ...[
                const CircularProgressIndicator(strokeWidth: 3),
                const SizedBox(height: 40),
              ] else ...[
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 60),
                const SizedBox(height: 20),
              ],
              Text(
                _loadingMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isError ? Colors.red : Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isError && _downloadProgress > 0) ...[
                const SizedBox(height: 30),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _downloadProgress,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                  ),
                ),
                const SizedBox(height: 12),
                Text('${(_downloadProgress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 12, color: Colors.blueAccent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showKnowledgeBaseInfo() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Local Knowledge Base', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Your agent has access to a private vector store. Ingest local files to provide private context for RAG retrieval.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _handleRealIngestion,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Pick and Ingest File'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
