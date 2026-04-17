import 'package:flutter_local_agent_kit/src/agent/agent_service.dart';
import 'package:flutter_local_agent_kit/src/llm/llm_service.dart';

/// Manages multiple specialized agents and routes queries to them.
class AgentOrchestrator {
  /// The list of specialized agents managed by this orchestrator.
  final Map<String, AgentService> agents;

  /// The primary LLM service used for routing.
  final LlmService llm;

  /// Creates an [AgentOrchestrator].
  AgentOrchestrator({
    required this.agents,
    required this.llm,
  });

  /// Processes a query by first determining the best agent for the task.
  Stream<String> run(String query) async* {
    final routingPrompt = _buildRoutingPrompt(query);
    String targetAgent = 'default';

    // Simple routing logic (can be improved with LLM classification)
    await for (final token in llm.generateStream(routingPrompt)) {
      if (token.contains('AGENT:')) {
        targetAgent = token.split('AGENT:').last.trim().toLowerCase();
        break;
      }
    }

    final agent = agents[targetAgent] ?? agents['default'];
    if (agent != null) {
      yield* agent.run(query);
    } else {
      yield "No suitable agent found for this request.";
    }
  }

  String _buildRoutingPrompt(String query) {
    final agentList = agents.keys.join(', ');
    return """Task: Classify which specialized agent should handle this user query.
Available Agents: $agentList

Rules:
1. Respond ONLY with "AGENT: [agent_name]"
2. If unsure, respond "AGENT: default"

User Query: $query
""";
  }
}
