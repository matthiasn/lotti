import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_emojis_row.dart';
import 'package:matrix/encryption.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('VerificationEmojisRow', () {
    testWidgets('renders emojis with names', (tester) async {
      final emojis = [
        KeyVerificationEmoji(0), // Dog
        KeyVerificationEmoji(1), // Cat
      ];

      await tester.pumpWidget(
        makeTestableWidget(
          VerificationEmojisRow(emojis),
        ),
      );

      // Each emoji should produce a Column with emoji text and name text
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('renders empty row when emojis is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const VerificationEmojisRow(null),
        ),
      );

      // Should render the Row but with no emoji children
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('renders empty row when emojis is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const VerificationEmojisRow([]),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('centers emojis in row', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          VerificationEmojisRow([KeyVerificationEmoji(0)]),
        ),
      );

      final row = tester.widget<Row>(find.byType(Row));

      expect(row.mainAxisAlignment, MainAxisAlignment.center);
    });
  });
}
