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

  /// Creates an [AgentChatMessage].
  AgentChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.timestamp,
    this.metadata,
  });

  /// Factory for creating a user message.
  factory AgentChatMessage.user(String content, {String? id}) {
    return AgentChatMessage(
      id: id ?? const Uuid().v4(),
      content: content,
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );
  }

  /// Factory for creating an assistant message.
  factory AgentChatMessage.assistant(String content, {String? id, Map<String, dynamic>? metadata}) {
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
  tool,
}

/// Represents the lifecycle state of the Agent Kit.
enum KitStatus {
  /// Not yet initialized.
  uninitialized,
  
  /// Currently booting native engines.
  initializing,
  
  /// All engines ready for inference.
  ready,
  
  /// Currently processing a query.
  processing,
  
  /// Initialization failed.
  error,
}
