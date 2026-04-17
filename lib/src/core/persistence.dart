import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';

/// Handles saving and loading agent conversation history to local storage.
class PersistenceService {
  /// The directory where sessions are stored.
  static const String _sessionsDir = 'agent_sessions';

  /// Saves a list of [AgentChatMessage] to a file named [sessionId].
  Future<void> saveSession(
      String sessionId, List<AgentChatMessage> messages) async {
    final directory = await _getSessionsDirectory();
    final file = File(p.join(directory.path, '$sessionId.json'));

    final data = messages.map((m) => m.toJson()).toList();
    await file.writeAsString(json.encode(data));
  }

  /// Loads a list of [AgentChatMessage] from a file named [sessionId].
  Future<List<AgentChatMessage>> loadSession(String sessionId) async {
    final directory = await _getSessionsDirectory();
    final file = File(p.join(directory.path, '$sessionId.json'));

    if (!await file.exists()) return [];

    final String content = await file.readAsString();
    final List<dynamic> decoded = json.decode(content) as List<dynamic>;

    return decoded
        .map((m) => AgentChatMessage.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Returns a list of all saved session IDs.
  Future<List<String>> listSessions() async {
    final directory = await _getSessionsDirectory();
    final List<FileSystemEntity> entities = await directory.list().toList();

    return entities
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .map((f) => p.basenameWithoutExtension(f.path))
        .toList();
  }

  /// Deletes a session by [sessionId].
  Future<void> deleteSession(String sessionId) async {
    final directory = await _getSessionsDirectory();
    final file = File(p.join(directory.path, '$sessionId.json'));
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _getSessionsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final sessionsDir = Directory(p.join(appDir.path, _sessionsDir));

    if (!await sessionsDir.exists()) {
      await sessionsDir.create(recursive: true);
    }

    return sessionsDir;
  }
}
