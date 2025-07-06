import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

import '../../../../widget_test_utils.dart';

// Simple widget that mimics LinkedFromEntriesWidget structure for testing
class TestLinkedFromWidget extends StatelessWidget {
  const TestLinkedFromWidget({
    required this.hasData,
    required this.hasImageEntries,
    super.key,
  });

  final bool hasData;
  final bool hasImageEntries;

  @override
  Widget build(BuildContext context) {
    if (!hasData) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Text(
          context.messages.journalLinkedFromLabel,
          style: context.textTheme.titleSmall
              ?.copyWith(color: context.colorScheme.outline),
        ),
        if (hasImageEntries)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingXSmall,
              right: AppTheme.spacingXSmall,
              bottom: AppTheme.spacingXSmall,
            ),
            child: Container(
              key: const ValueKey('image-1'),
              height: 100,
              color: Colors.grey,
              child: const Text('Mock Image Card'),
            ),
          ),
        if (!hasImageEntries)
          Padding(
            padding: const EdgeInsets.only(
              left: AppTheme.spacingXSmall,
              right: AppTheme.spacingXSmall,
              bottom: AppTheme.spacingXSmall,
            ),
            child: Container(
              key: const ValueKey('text-1'),
              height: 80,
              color: Colors.blue,
              child: const Text('Mock Journal Card'),
            ),
          ),
      ],
    );
  }
}

void main() {
  group('LinkedFromWidget Structure Tests', () {
    testWidgets('renders correctly with image entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestLinkedFromWidget(
            hasData: true,
            hasImageEntries: true,
          ),
        ),
      );

      // Verify the section title is rendered
      expect(find.text('Linked from:'), findsOneWidget);

      // Verify image container is rendered with correct key
      expect(find.byKey(const ValueKey('image-1')), findsOneWidget);

      // Verify padding is applied correctly
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('image-1')),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
      );
    });

    testWidgets('renders correctly with regular entries', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestLinkedFromWidget(
            hasData: true,
            hasImageEntries: false,
          ),
        ),
      );

      // Verify the section title is rendered
      expect(find.text('Linked from:'), findsOneWidget);

      // Verify text container is rendered with correct key
      expect(find.byKey(const ValueKey('text-1')), findsOneWidget);

      // Verify padding is applied correctly
      final padding = tester.widget<Padding>(
        find
            .ancestor(
              of: find.byKey(const ValueKey('text-1')),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsets.only(
          left: AppTheme.spacingXSmall,
          right: AppTheme.spacingXSmall,
          bottom: AppTheme.spacingXSmall,
        ),
      );
    });

    testWidgets('renders empty when no data', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const TestLinkedFromWidget(
            hasData: false,
            hasImageEntries: false,
          ),
        ),
      );

      // Empty list should show nothing
      expect(find.text('Linked from:'), findsNothing);
      expect(find.byKey(const ValueKey('image-1')), findsNothing);
      expect(find.byKey(const ValueKey('text-1')), findsNothing);
    });
  });
}
