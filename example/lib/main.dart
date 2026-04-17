import 'package:flutter/material.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';

void main() {
  runApp(const LocalAgentDemo());
}

/// A comprehensive demo app showcasing the full capabilities of the Local Agent Kit.
class LocalAgentDemo extends StatelessWidget {
  const LocalAgentDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Local Agent Studio',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: Brightness.dark,
        ),
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

  bool _isInit = false;
  double _downloadProgress = 0.0;
  String _statusMessage = 'System Idle';
  String _activeModelName = 'Checking...';
  int _ragDocCount = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() => _statusMessage = 'Checking model weights...');

    const modelId = 'llama-3.2-1b-instruct';
    final recommended =
        ModelManager.recommendedModels.firstWhere((m) => m.id == modelId);
    setState(() => _activeModelName = recommended.name);

    final isDownloaded = await _kit.models.isModelDownloaded(modelId);
    final modelPath = await _kit.models.getLocalPath(modelId);

    if (!isDownloaded) {
      setState(
          () => _statusMessage = 'Downloading ${recommended.name} (~700MB)...');
      try {
        await _kit.models.downloadModel(
          recommended,
          onProgress: (progress) =>
              setState(() => _downloadProgress = progress),
        );
      } catch (e) {
        setState(() => _statusMessage = 'Download Failed: $e');
        return;
      }
    }

    setState(() => _statusMessage = 'Booting Native Engines...');

    try {
      await _kit.initialize(modelPath: modelPath);
      setState(() {
        _isInit = true;
        _statusMessage = 'AI Core Online';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Boot Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Agent Studio',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [_buildStatusChip()],
      ),
      body: _isInit
          ? Column(
              children: [
                _buildControlPanel(),
                const Divider(height: 1),
                Expanded(
                  child: AgentChatView(
                    onMessage: (query) => _kit.runAgent(query),
                    welcomeMessage:
                        'I am your resident AI agent. Everything we discuss stays on this device.',
                    suggestions: const [
                      '🕵️ Who are you?',
                      '📅 What is the time?',
                      '🧮 Solve: (15 * 8) + 120',
                      '📚 How does RAG work?',
                      '🚀 Performance test',
                    ],
                  ),
                ),
              ],
            )
          : _buildLoadingState(),
    );
  }

  Widget _buildControlPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resident LLM: $_activeModelName',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text('RAG Knowledge: $_ragDocCount documents',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Simulated knowledge injection for demo
              setState(() => _ragDocCount++);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Document indexed into local vector base.')),
              );
            },
            icon: const Icon(Icons.add_link),
            label: const Text('Inject'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    final isError =
        _statusMessage.contains('Error') || _statusMessage.contains('Failed');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isError
            ? Colors.red.withValues(alpha: 0.2)
            : (_isInit
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.orange.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              isError ? Colors.red : (_isInit ? Colors.green : Colors.orange),
        ),
      ),
      child: Text(
        isError ? 'ERROR' : (_isInit ? 'SECURE' : 'INITIALIZING'),
        style: TextStyle(
          color:
              isError ? Colors.red : (_isInit ? Colors.green : Colors.orange),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final isError =
        _statusMessage.contains('Error') || _statusMessage.contains('Failed');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!isError) const CircularProgressIndicator(),
            if (isError)
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isError ? Colors.red : null,
                  ),
            ),
            if (!isError && _downloadProgress > 0) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 240,
                child: LinearProgressIndicator(
                    value: _downloadProgress,
                    borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 8),
              Text('${(_downloadProgress * 100).toInt()}%',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
            if (isError) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _bootstrap(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Boot Sequence'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
