import 'package:uuid/uuid.dart';

/// Represents a single message in an AI conversation.
class AgentChatMessage {
  /// Unique identifier for the message.
  final String id;

  /// The text content of the message.
  final String content;

  /// Whether the message is from the user, assistant, or system.
  final MessageRole role;

  /// When the message was created.
  final DateTime timestamp;

  /// Optional structured data associated with the message.
  final Map<String, dynamic>? metadata;

  /// Optional image data for multimodal queries.
  final List<int>? imageBytes;

  /// Returns true if the message contains an image.
  bool get hasImage => imageBytes != null;

  /// Creates an [AgentChatMessage].
  AgentChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.metadata,
    this.imageBytes,
  });

  /// Factory for creating a user message.
  factory AgentChatMessage.user(String content,
      {String? id, List<int>? imageBytes}) {
    return AgentChatMessage(
      id: id ?? const Uuid().v4(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
      imageBytes: imageBytes,
    );
  }

  /// Factory for creating an assistant message.
  factory AgentChatMessage.assistant(String content,
      {String? id, Map<String, dynamic>? metadata}) {
    return AgentChatMessage(
      id: id ?? const Uuid().v4(),
      content: content,
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Factory for creating a system message.
  factory AgentChatMessage.system(String content, {String? id}) {
    return AgentChatMessage(
      id: id ?? const Uuid().v4(),
      content: content,
      role: MessageRole.system,
      timestamp: DateTime.now(),
    );
  }

  /// Converts the message to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      if (imageBytes != null) 'imageBytes': imageBytes,
    };
  }

  /// Creates a message from a JSON map.
  factory AgentChatMessage.fromJson(Map<String, dynamic> json) {
    return AgentChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      role: MessageRole.values.firstWhere((e) => e.name == json['role']),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
      imageBytes: json['imageBytes'] != null
          ? List<int>.from(json['imageBytes'] as List)
          : null,
    );
  }
}

/// Possible roles in a conversation.
enum MessageRole {
  /// System instructions.
  system,

  /// Human user.
  user,

  /// AI Assistant.
  assistant,

  /// Execution result from a tool.
  tool;

  /// Helper to convert string to role.
  static MessageRole fromString(String role) {
    return MessageRole.values.firstWhere(
      (e) => e.name == role.toLowerCase(),
      orElse: () => MessageRole.user,
    );
  }
}



/// A chunk of retrieved context with source metadata.
class RetrievalResult {
  /// The text content of the chunk.
  final String content;

  /// Metadata about the source document.
  final SourceMetadata source;

  /// Similarity score (0.0 to 1.0).
  final double score;

  /// Creates a [RetrievalResult].
  RetrievalResult({
    required this.content,
    required this.source,
    required this.score,
  });

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'content': content,
        'source': source.toJson(),
        'score': score,
      };

  /// Creates from JSON.
  factory RetrievalResult.fromJson(Map<String, dynamic> json) =>
      RetrievalResult(
        content: json['content'] as String,
        source: SourceMetadata.fromJson(json['source'] as Map<String, dynamic>),
        score: (json['score'] as num).toDouble(),
      );
}

/// Metadata about a source document used in RAG.
class SourceMetadata {
  /// Name or title of the document.
  final String title;

  /// Path or URL to the original file.
  final String? filePath;

  /// Page number if applicable.
  final int? pageNumber;

  /// Creates [SourceMetadata].
  SourceMetadata({
    required this.title,
    this.filePath,
    this.pageNumber,
  });

  /// Converts to JSON.
  Map<String, dynamic> toJson() => {
        'title': title,
        'filePath': filePath,
        'pageNumber': pageNumber,
      };

  /// Creates from JSON.
  factory SourceMetadata.fromJson(Map<String, dynamic> json) => SourceMetadata(
        title: json['title'] as String,
        filePath: json['filePath'] as String?,
        pageNumber: json['pageNumber'] as int?,
      );
}
