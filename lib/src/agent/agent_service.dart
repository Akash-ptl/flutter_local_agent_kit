import 'dart:async';
import 'dart:convert';
import 'package:flutter_local_agent_kit/src/agent/tools.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';
import 'package:flutter_local_agent_kit/src/core/models.dart';

/// Service orchestrating the Reason-Act (ReAct) loop for the agent.
class AgentService {
  /// The LLM provider for the agent.
  final LlmService llm;

  /// The list of tools available to the agent.
  final List<BaseTool> tools;

  /// Optional custom instructions for the agent's persona.
  final String? customInstructions;

  /// Maximum number of Reason-Act iterations.
  final int maxIterations;

  /// Creates an [AgentService].
  AgentService(
    this.llm,
    this.tools, {
    this.customInstructions,
    this.maxIterations = 5,
  });

  String _buildSystemPrompt() {
    final toolsDesc = tools
        .map((t) =>
            '- ${t.name}: ${t.description}. Params: ${jsonEncode(t.parameterSchema)}')
        .join('\n');

    return """${customInstructions ?? 'You are a highly efficient autonomous AI agent running locally.'}
You have access to specialized tools to assist the user accurately.

# RULES:
1. ALWAYS start with 'Thought:' to describe your reasoning.
2. To use a tool, use this EXACT format:
   Thought: [Reasoning]
   Action: [tool_name]
   Action Input: [json_arguments]

3. To finish, use this format:
   Final Answer: [Your response to the user]

4. Never hallucinate observations. Only use the data provided in the 'Observation' sections.
5. Provide the 'Final Answer' only after you have gathered all necessary information.

# AVAILABLE TOOLS:
$toolsDesc

Begin!""";
  }

  /// Runs the agentic loop for a given query.
  Stream<String> run(String query) async* {
    List<AgentChatMessage> conversation = [
      AgentChatMessage.system(_buildSystemPrompt()),
      AgentChatMessage.user(query),
    ];

    for (int i = 0; i < maxIterations; i++) {
      final prompt = llm.format(conversation);

      String fullResponse = "";
      await for (final token in llm.generateStream(prompt)) {
        fullResponse += token;
      }

      if (fullResponse.contains('Final Answer:')) {
        yield fullResponse.split('Final Answer:').last.trim();
        return;
      }

      final action = _parseAction(fullResponse);
      if (action != null) {
        final toolName = action.name;
        final toolInput = action.input;

        try {
          final tool = tools.firstWhere((t) => t.name == toolName);
          yield "Thinking (using ${tool.name})...";

          final observation = await tool.call(toolInput);

          conversation.add(AgentChatMessage.assistant(fullResponse));
          conversation
              .add(AgentChatMessage.system("Observation: $observation"));

          continue;
        } catch (e) {
          yield "Error using $toolName: $e";
          return;
        }
      }

      // If no valid action or answer found, yield the raw response and stop
      yield fullResponse.replaceAll('Thought:', '').trim();
      return;
    }

    yield "I've reached my maximum reasoning limit without a final answer.";
  }

  _ParsedAction? _parseAction(String text) {
    try {
      final actionMatch = RegExp(r'Action:\s*(.*)').firstMatch(text);
      final inputMatch =
          RegExp(r'Action Input:\s*(\{.*\})', dotAll: true).firstMatch(text);

      if (actionMatch != null && inputMatch != null) {
        final name = actionMatch.group(1)?.trim() ?? '';
        var jsonStr = inputMatch.group(1)?.trim() ?? '{}';

        // Handle LLM adding code block markers
        jsonStr =
            jsonStr.replaceAll('```json', '').replaceAll('```', '').trim();

        final input = Map<String, dynamic>.from(json.decode(jsonStr) as Map);
        return _ParsedAction(name, input);
      }
    } catch (_) {
      // Return null on parsing failure to fallback to raw response
    }
    return null;
  }
}

class _ParsedAction {
  final String name;
  final Map<String, dynamic> input;
  _ParsedAction(this.name, this.input);
}
