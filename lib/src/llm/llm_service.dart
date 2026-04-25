import 'dart:async';
import 'dart:typed_data';
import 'package:llamadart/llamadart.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:flutter_local_agent_kit/src/llm/prompt_templates.dart';

/// A wrapper around [LlamaEngine] to handle streaming and prompt templating.
class LlmService {
  /// The underlying raw llama engine.
  final LlamaEngine engine;

  /// The template used for formatting prompts.
  final PromptTemplate template;

  /// The context size (maximum memory window) of the loaded model.
  final int contextSize;

  /// Creates an [LlmService].
  LlmService({
    required this.engine,
    required this.template,
    required this.contextSize,
  });

  /// Generates a streaming response for the given prompt.
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int? maxTokens,
  }) {
    return engine.generate(
      prompt,
      params: GenerationParams(
        temp: temperature,
        maxTokens: maxTokens ?? 1024,
        stopSequences: [template.stopSequence],
      ),
    );
  }

  /// Generates a streaming response from a list of [AgentChatMessage].
  /// This handles multimodal inputs (images) automatically.
  Stream<String> generateChatStream(
    List<AgentChatMessage> messages, {
    double temperature = 0.7,
    int? maxTokens,
  }) {
    // If no images, fallback to faster string-based generation
    if (!messages.any((m) => m.imageBytes != null)) {
      return generateStream(format(messages),
          temperature: temperature, maxTokens: maxTokens);
    }

    // Convert to llamadart multimodal format
    final List<LlamaContentPart> contentParts = [];
    for (final m in messages) {
      contentParts.add(LlamaTextContent(m.content));
      if (m.imageBytes != null) {
        contentParts.add(LlamaImageContent(bytes: Uint8List.fromList(m.imageBytes!)));
      }
    }

    return ChatSession(engine).create(
      contentParts,
      params: GenerationParams(
        temp: temperature,
        maxTokens: maxTokens ?? 1024,
        stopSequences: [template.stopSequence],
      ),
    ).map((chunk) => chunk.toString());
  }

  /// Formats a list of messages using the active model template.
  String format(List<AgentChatMessage> messages) {
    return template.formatMessages(messages);
  }
}
