import 'package:flutter/material.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';
import 'dart:io';

/// Entry point for the example app.
void main() {
  runApp(const MyApp());
}

/// The main application widget.
class MyApp extends StatelessWidget {
  /// Creates a [MyApp] widget.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      home: const HomeScreen(),
    );
  }
}

/// The stateful home screen widget.
class HomeScreen extends StatefulWidget {
  /// Creates a [HomeScreen] widget.
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterLocalAgentKit _agentKit = FlutterLocalAgentKit();
  bool _isInitialized = false;
  String _status = 'Standby';

  @override
  void dispose() {
    _agentKit.dispose();
    super.dispose();
  }

  Future<void> _initializeKit() async {
    setState(() => _status = 'Initializing AI...');
    
    // NOTE: Update this path to a real GGUF model on your device.
    const modelPath = '/storage/emulated/0/Download/llama-3-8b.gguf'; 

    try {
      if (!File(modelPath).existsSync()) {
        throw Exception('Model file not found. Please update modelPath in main.dart.');
      }

      await _agentKit.initialize(modelPath: modelPath);
      setState(() {
        _isInitialized = true;
        _status = 'AI Ready';
      });
    } catch (e) {
      setState(() => _status = 'Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isInitialized 
        ? AgentChatView(agentKit: _agentKit, title: 'Local AI Maven')
        : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.psychology_outlined, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 24),
                Text(_status, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                const SizedBox(height: 32),
                if (!_isInitialized && !_status.contains('Initializing'))
                  ElevatedButton.icon(
                    onPressed: _initializeKit,
                    icon: const Icon(Icons.flash_on_rounded),
                    label: const Label('Wake Up Local Agent'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
              ],
            ),
          ),
    );
  }
}

/// A simple label helper for the UI.
class Label extends StatelessWidget {
  /// The text to display in the label.
  final String text;
  
  /// Creates a [Label] widget.
  const Label(this.text, {super.key});
  
  @override
  Widget build(BuildContext context) => Text(text);
}

