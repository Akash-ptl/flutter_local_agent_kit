import 'package:mcp_dart/mcp_dart.dart';
import 'package:flutter_local_agent_kit/src/agent/tools.dart';

/// Manages connections to Model Context Protocol (MCP) servers.
class McpService {
  final List<McpClient> _clients = [];

  /// Connects to a new MCP server using the provided [transport].
  Future<McpClient> connect(Transport transport) async {
    final client = McpClient(
      Implementation(name: 'flutter-local-agent-kit', version: '1.1.1'),
    );
    await client.connect(transport);
    _clients.add(client);
    return client;
  }

  /// Lists all tools available across all connected MCP servers.
  Future<List<BaseTool>> getTools() async {
    final List<BaseTool> allTools = [];
    
    for (final client in _clients) {
      final result = await client.listTools();
      for (final tool in result.tools) {
        allTools.add(McpTool(client, tool));
      }
    }
    
    return allTools;
  }

  /// Disconnects all MCP clients.
  Future<void> dispose() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();
  }
}

/// A [BaseTool] implementation that wraps a remote MCP tool.
class McpTool extends BaseTool {
  final McpClient client;
  final Tool definition;

  McpTool(this.client, this.definition)
      : super(
          name: definition.name,
          description: definition.description ?? '',
          parameterSchema: definition.inputSchema.toJson(),
        );

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    try {
      final result = await client.callTool(
        CallToolRequest(name: name, arguments: arguments),
      );
      return result.content.map((c) {
        if (c is TextContent) return c.text;
        return c.toString();
      }).join('\n');
    } catch (e) {
      return "MCP Error: $e";
    }
  }
}
