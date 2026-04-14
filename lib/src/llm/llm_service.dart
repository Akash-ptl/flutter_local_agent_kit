import 'dart:async';
import 'package:llamadart/llamadart.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';
import 'package:flutter_local_agent_kit/src/llm/prompt_templates.dart';

/// A wrapper around [LlamaEngine] to handle streaming and prompt templating.
class LlmService {
  /// The underlying raw llama engine.
  final LlamaEngine engine;
  
  /// The template used for formatting prompts.
  final PromptTemplate template;

  /// Creates an [LlmService].
  LlmService({
    required this.engine,
    required this.template,
  });

  /// Generates a streaming response for the given prompt.
  Stream<String> generateStream(String prompt, {
    double temperature = 0.7,
    int maxTokens = 1024,
  }) {
    return engine.generate(
      prompt,
      params: GenerationParams(
        temp: temperature,
        maxTokens: maxTokens,
        stopSequences: [template.stopSequence],
      ),
    );
  }

  /// Formats a list of messages using the active model template.
  String format(List<AgentChatMessage> messages) {
    return template.formatMessages(messages);
  }
}
