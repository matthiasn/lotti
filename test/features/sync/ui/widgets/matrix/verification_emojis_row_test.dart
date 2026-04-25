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

    testWidgets('renders empty wrap when emojis is null', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const VerificationEmojisRow(null),
        ),
      );

      // Should render the Wrap with no emoji children.
      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children, isEmpty);
    });

    testWidgets('renders empty wrap when emojis is empty', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const VerificationEmojisRow([]),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));
      expect(wrap.children, isEmpty);
    });

    testWidgets('centers emojis in the wrap', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          VerificationEmojisRow([KeyVerificationEmoji(0)]),
        ),
      );

      final wrap = tester.widget<Wrap>(find.byType(Wrap));

      expect(wrap.alignment, WrapAlignment.center);
      expect(wrap.runAlignment, WrapAlignment.center);
    });

    testWidgets(
      'wraps the 7-emoji verification sequence onto multiple lines '
      'on a narrow Samsung-sized viewport without overflowing',
      (tester) async {
        // The Matrix verification sequence is 7 emojis. On a narrow phone
        // (≈360 dp wide) the row would overflow horizontally if rendered
        // as a single Row — the Wrap layout must spill onto a second line.
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(360, 800);

        final emojis = List<KeyVerificationEmoji>.generate(
          7,
          KeyVerificationEmoji.new,
        );

        await tester.pumpWidget(
          makeTestableWidget(
            SizedBox(
              width: 360,
              child: VerificationEmojisRow(emojis),
            ),
          ),
        );
        await tester.pump();

        // No overflow should be reported by the framework.
        expect(tester.takeException(), isNull);

        // All 7 emoji cells render.
        final wrap = tester.widget<Wrap>(find.byType(Wrap));
        expect(wrap.children, hasLength(7));

        // At least one cell wraps onto a row below the first cell — proving
        // the layout actually spilled onto a second line on this width.
        final cellTops = wrap.children
            .map(
              (child) => tester.getTopLeft(find.byWidget(child)).dy,
            )
            .toSet();
        expect(cellTops.length, greaterThan(1));
      },
    );
  });
}
