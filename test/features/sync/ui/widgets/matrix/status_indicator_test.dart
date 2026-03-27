import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/status_indicator.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  group('StatusIndicator', () {
    testWidgets('renders circular container with given color', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const StatusIndicator(
            Colors.green,
            semanticsLabel: 'Connected',
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, Colors.green);
      expect(decoration.shape, BoxShape.circle);
    });

    testWidgets('applies semantics label', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const StatusIndicator(
            Colors.red,
            semanticsLabel: 'Disconnected',
          ),
        ),
      );

      expect(
        find.bySemanticsLabel('Disconnected'),
        findsOneWidget,
      );
    });

    testWidgets('has box shadow with status color', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const StatusIndicator(
            Colors.blue,
            semanticsLabel: 'Active',
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow, hasLength(1));
      expect(decoration.boxShadow!.first.color, Colors.blue);
    });

    testWidgets('has correct dimensions', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const StatusIndicator(
            Colors.orange,
            semanticsLabel: 'Warning',
          ),
        ),
      );

      final container = tester.widget<Container>(find.byType(Container));

      expect(container.constraints?.maxHeight, 30);
      expect(container.constraints?.maxWidth, 30);
    });
  });
}
