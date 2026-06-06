import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/helpers.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('EntryTextWidget', () {
    testWidgets('renders the text with the default 5-line clamp and padding', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(const EntryTextWidget('hello entry')),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('hello entry'));
      expect(text.maxLines, 5);
      expect(text.softWrap, isTrue);

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('hello entry'),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.symmetric(vertical: 8));
    });

    testWidgets('honors custom maxLines and padding', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const EntryTextWidget(
            'custom',
            maxLines: 2,
            padding: EdgeInsets.all(16),
          ),
        ),
      );
      await tester.pump();

      final text = tester.widget<Text>(find.text('custom'));
      expect(text.maxLines, 2);

      final padding = tester.widget<Padding>(
        find.ancestor(
          of: find.text('custom'),
          matching: find.byType(Padding),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(16));
    });
  });
}
