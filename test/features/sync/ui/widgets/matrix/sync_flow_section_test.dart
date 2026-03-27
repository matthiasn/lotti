import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/sync_flow_section.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('SyncFlowSection', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Section Content'),
          ),
        ),
      );

      expect(find.text('Section Content'), findsOneWidget);
    });

    testWidgets('applies default padding', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Content'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).last);

      expect(padding.padding, const EdgeInsets.all(16));
    });

    testWidgets('accepts custom padding', (tester) async {
      const customPadding = EdgeInsets.symmetric(horizontal: 8);

      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            padding: customPadding,
            child: Text('Content'),
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).last);

      expect(padding.padding, customPadding);
    });

    testWidgets('wraps child in DecoratedBox', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Content'),
          ),
        ),
      );

      expect(find.byType(DecoratedBox), findsOneWidget);
    });

    testWidgets('decorated box has rounded border', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const SyncFlowSection(
            child: Text('Content'),
          ),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(
        decoration.borderRadius,
        BorderRadius.circular(16),
      );
    });
  });
}
