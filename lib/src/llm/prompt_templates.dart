import 'package:flutter_local_agent_kit/src/core/models.dart';

/// Abstract base class for all prompt templates.
/// 
/// Templates responsible for formatting messages into a single prompt string
/// that the specific LLM architecture expects.
abstract class PromptTemplate {
  /// The sequence that signals the model to stop generating.
  String get stopSequence;
  
  /// Formats a list of [messages] into a raw prompt string.
  String formatMessages(List<AgentChatMessage> messages);
}

/// The prompt template specifically tuned for Llama 3 models.
class Llama3Template extends PromptTemplate {
  @override
  String get stopSequence => '<|eot_id|>';

  @override
  String formatMessages(List<AgentChatMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final roleName = msg.role.name;
      buffer.write('<|begin_of_text|><|start_header_id|>$roleName<|end_header_id|>\n\n');
      buffer.write('${msg.content}<|eot_id|>');
    }

    buffer.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
    return buffer.toString();
  }
}

/// A simple template for general-purpose models (mostly legacy).
class SimplePromptTemplate extends PromptTemplate {
  @override
  String get stopSequence => '\nUser:';

  @override
  String formatMessages(List<AgentChatMessage> messages) {
    final buffer = StringBuffer();
    for (final msg in messages) {
      final roleName = msg.role.name.toUpperCase();
      buffer.write('\n$roleName: ${msg.content}');
    }
    buffer.write('\nASSISTANT: ');
    return buffer.toString();
  }
}
