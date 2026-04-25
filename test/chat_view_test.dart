import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_agent_kit/flutter_local_agent_kit.dart';

void main() {
  group('AgentChatView', () {
    testWidgets(
        'replaces placeholder bubble with error message when stream fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentChatView(
              onMessage: (_, {imageBytes, onCitations}) async* {
                throw Exception('boom');
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Hello', findRichText: true), findsOneWidget);
      expect(
        find.textContaining(
            'Sorry, something went wrong while generating a response.',
            findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('Error: Exception: boom', findRichText: true), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });
}
