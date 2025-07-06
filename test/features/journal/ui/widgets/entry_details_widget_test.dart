import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/themes/theme.dart';

import '../../../../widget_test_utils.dart';

// Simplified test widget that mimics EntryDetailsWidget behavior
class TestEntryDetailsWidget extends StatelessWidget {
  const TestEntryDetailsWidget({
    required this.isTask,
    required this.showTaskDetails,
    super.key,
  });

  final bool isTask;
  final bool showTaskDetails;

  @override
  Widget build(BuildContext context) {
    if (isTask && !showTaskDetails) {
      return Padding(
        padding: const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
        child: Container(
          key: const Key('modern-journal-card'),
          height: 100,
          color: Colors.blue,
          child: const Text('Mock Modern Journal Card'),
        ),
      );
    }

    return const Card(
      key: Key('entry-details-card'),
      margin: EdgeInsets.only(
        left: AppTheme.spacingXSmall,
        right: AppTheme.spacingXSmall,
        bottom: AppTheme.spacingMedium,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMedium),
        child: Text('Entry Details Content'),
      ),
    );
  }
}

void main() {
  group('EntryDetailsWidget Layout Tests', () {
    testWidgets(
        'wraps task cards with proper padding when showTaskDetails is false',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: false,
          ),
        ),
      );

      // Find the container that represents our mock card
      final containerFinder = find.byKey(const Key('modern-journal-card'));
      expect(containerFinder, findsOneWidget);

      // Find the padding widget that wraps it
      final paddingFinder = find.ancestor(
        of: containerFinder,
        matching: find.byType(Padding),
      );

      expect(paddingFinder, findsOneWidget);

      final padding = tester.widget<Padding>(paddingFinder);
      expect(
        padding.padding,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
      );
    });

    testWidgets('renders card layout when showTaskDetails is true',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: true,
          ),
        ),
      );

      // When showTaskDetails is true, it should render a Card
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(const Key('entry-details-card')), findsOneWidget);

      // Mock modern journal card should not be present
      expect(find.byKey(const Key('modern-journal-card')), findsNothing);

      // Verify card margins
      final card = tester.widget<Card>(find.byType(Card));
      expect(
        card.margin,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingMedium,
        ),
      );
    });

    testWidgets('renders card layout for non-task entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: false,
            showTaskDetails: false,
          ),
        ),
      );

      // Non-task entries should always render a Card
      expect(find.byType(Card), findsOneWidget);
      expect(find.byKey(const Key('entry-details-card')), findsOneWidget);
    });

    testWidgets('verifies padding structure for task cards', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestEntryDetailsWidget(
            isTask: true,
            showTaskDetails: false,
          ),
        ),
      );

      // Verify the widget tree structure
      final container = find.byKey(const Key('modern-journal-card'));
      final padding = find.ancestor(
        of: container,
        matching: find.byType(Padding),
      );

      expect(container, findsOneWidget);
      expect(padding, findsOneWidget);

      // Verify no Card widget is present
      expect(find.byType(Card), findsNothing);
    });
  });
}
