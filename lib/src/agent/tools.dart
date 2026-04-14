import 'package:math_expressions/math_expressions.dart';

/// Base class for all tools the agent can use.
/// 
/// Tools allow the agent to interact with the outside world (APIs, Math, etc.)
abstract class BaseTool {
  /// Unique name of the tool (e.g. 'calculator').
  final String name;
  
  /// Description explaining to the AI when to use this tool.
  final String description;
  
  /// A JSON schema describing the required parameters.
  final Map<String, dynamic> parameterSchema;

  /// Creates a [BaseTool].
  BaseTool({
    required this.name,
    required this.description,
    required this.parameterSchema,
  });

  /// Executes the tool's logic based on [arguments].
  Future<String> call(Map<String, dynamic> arguments);
}

/// A built-in tool for evaluating mathematical expressions.
class CalculatorTool extends BaseTool {
  /// Creates a [CalculatorTool].
  CalculatorTool() : super(
    name: 'calculator',
    description: 'Useful for performing mathematical calculations.',
    parameterSchema: {
      'expression': 'The math expression to evaluate (e.g., "2 + 2")'
    },
  );

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    final expression = (arguments['expression'] as String?) ?? '';
    if (expression.isEmpty) return 'Error: Empty expression';
    
    try {
      final p = ShuntingYardParser();
      final exp = p.parse(expression);
      final cm = ContextModel();
      // ignore: deprecated_member_use
      final result = exp.evaluate(EvaluationType.REAL, cm);
      return result.toString();
    } catch (e) {
      return "Error evaluating expression: $e";
    }
  }
}

/// A built-in tool for retrieving the current device time.
class DateTimeTool extends BaseTool {
  /// Creates a [DateTimeTool].
  DateTimeTool() : super(
    name: 'get_time',
    description: 'Returns the current date and time.',
    parameterSchema: {},
  );

  @override
  Future<String> call(Map<String, dynamic> arguments) async {
    return DateTime.now().toIso8601String();
  }
}
