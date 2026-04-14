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

  /// Creates an [AgentService].
  AgentService(this.llm, this.tools);

  String _buildSystemPrompt() {
    final toolsDesc = tools.map((t) => '- ${t.name}: ${t.description}. Params: ${jsonEncode(t.parameterSchema)}').join('\n');
    
    return """You are an autonomous agent. You can use tools to answer questions.
Available Tools:
$toolsDesc

To use a tool, use the following format:
Thought: [Reasoning about what to do]
Action: [tool_name]
Action Input: [json_arguments]

When you have the final answer, use:
Final Answer: [The actual answer to the user]

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
          final tool = tools.firstWhere((t) => t.name == toolName);
          yield "Thinking (using ${tool.name})...";
          
          final observation = await tool.call(toolInput);
          
          conversation.add(AgentChatMessage.assistant(fullResponse));
          conversation.add(AgentChatMessage.system("Observation: $observation"));
          
          continue; 
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
      return Map<String, dynamic>.from(decoded as Map);
    } catch (e) {
      return {};
    }
  }
}
