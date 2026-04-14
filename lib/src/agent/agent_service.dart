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

  /// Creates an [AgentService].
  AgentService(this.llm, this.tools, {this.customInstructions});

  String _buildSystemPrompt() {
    final toolsDesc = tools.map((t) => '- ${t.name}: ${t.description}. Params: ${jsonEncode(t.parameterSchema)}').join('\n');
    
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
5. Be concise and professional.

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

    int maxIterations = 3;
    
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

      if (fullResponse.contains('Action:')) {
        final toolName = _parseAction(fullResponse);
        final toolInput = _parseInput(fullResponse);
        
        if (toolName != null) {
          try {
            final tool = tools.firstWhere((t) => t.name == toolName);
            yield "Thinking (using ${tool.name})...";
            
            final observation = await tool.call(toolInput);
            final observationStr = observation?.toString() ?? "No output received from tool.";
            
            conversation.add(AgentChatMessage.assistant(fullResponse));
            conversation.add(AgentChatMessage.system("Observation: $observationStr"));
            
            continue; 
          } catch (e) {
            yield "Error using $toolName: $e";
            return;
          }
        }
      }

      
      yield fullResponse;
      return;
    }
  }

  String? _parseAction(String text) {
    final match = RegExp(r'Action: (.*)').firstMatch(text);
    return match?.group(1)?.trim();
  }

  Map<String, dynamic> _parseInput(String text) {
    final match = RegExp(r'Action Input: (.*)').firstMatch(text);
    final jsonStr = match?.group(1)?.trim() ?? '{}';
    try {
      final decoded = json.decode(jsonStr);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return {};
    } catch (e) {
      return {};
    }
  }

}
