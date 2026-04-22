import 'package:flutter/material.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';

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
      await _kit.initialize(modelPath: modelPath);

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
    if (mounted) Navigator.pop(context); // Close drawer
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

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return _buildLoadingScreen();

    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: Column(
          children: [
            const Text('Local Agent Studio',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(_activeSessionId,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.blueAccent.withValues(alpha: 0.7))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_motion_rounded, size: 20),
            onPressed: _showKnowledgeBaseInfo,
            tooltip: 'Knowledge Base',
          ),
        ],
      ),
      body: AgentChatView(
        onMessage: (query) => _kit.runAgent(query),
        initialHistory: _currentHistory,
        onHistoryChanged: (history) {
          _currentHistory = history;
          _kit.saveSession(_activeSessionId, history);
        },
        suggestions: const [
          '🕵️ Who are you?',
          '📅 What is the current time?',
          '🧮 Solve: (124 * 3) / 2',
          '🔒 Is this conversation private?',
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
                  Text('Session Manager',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          ListTile(
            leading:
                const Icon(Icons.add_comment_rounded, color: Colors.blueAccent),
            title: const Text('New Chat',
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                  leading: Icon(isActive
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded),
                  title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _switchSession(id),
                  trailing: id != 'default_session'
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          onPressed: () async {
                            await _kit.persistence.deleteSession(id);
                            final sessions =
                                await _kit.persistence.listSessions();
                            setState(() => _allSessions = sessions.isEmpty
                                ? ['default_session']
                                : sessions);
                          },
                        )
                      : null,
                );
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Engine Settings'),
            onTap: () {},
          ),
          const SizedBox(height: 16),
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
                const Icon(Icons.error_outline_rounded,
                    color: Colors.red, size: 60),
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
                    style: const TextStyle(
                        fontSize: 12, color: Colors.blueAccent)),
              ],
              if (isError) ...[
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: _initializeKit,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                ),
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
            const Text('Local Knowledge Base',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const Text(
              'Your agent has access to a private vector store. You can ingest files like PDFs or JSONs to give the AI context about your private data.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Ingest PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.data_object_rounded),
                    label: const Text('Ingest JSON'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
