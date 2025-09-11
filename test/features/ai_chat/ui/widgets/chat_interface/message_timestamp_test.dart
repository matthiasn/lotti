import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/message_timestamp.dart';

void main() {
  Widget wrap(Widget child, {ThemeData? theme}) => MaterialApp(
        theme: theme ?? ThemeData.light(),
        home: Scaffold(body: Center(child: child)),
      );

  group('MessageTimestamp', () {
    testWidgets('formats time as HH:mm', (tester) async {
      final ts = DateTime(2025, 1, 2, 3, 4);
      await tester.pumpWidget(wrap(
        MessageTimestamp(timestamp: ts, isUser: false),
      ));

      expect(find.text('03:04'), findsOneWidget);
    });

    testWidgets('aligns left for user and right for assistant', (tester) async {
      final ts = DateTime(2025, 1, 2, 12, 30);

      await tester.pumpWidget(wrap(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MessageTimestamp(timestamp: ts, isUser: true),
            MessageTimestamp(timestamp: ts, isUser: false),
          ],
        ),
      ));

      final texts = tester.widgetList<Text>(find.text('12:30')).toList();
      expect(texts.length, 2);
      expect(texts[0].textAlign, TextAlign.left);
      expect(texts[1].textAlign, TextAlign.right);
    });
  });
}
