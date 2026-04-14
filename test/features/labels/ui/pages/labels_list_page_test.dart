import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/features/labels/state/labels_list_controller.dart';
import 'package:lotti/features/labels/ui/pages/labels_list_page.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

void main() {
  group('LabelsListPage Widget Tests', () {
    late MockLabelsRepository mockRepository;

    setUp(() async {
      await setUpTestGetIt();
      mockRepository = MockLabelsRepository();
    });

    tearDown(tearDownTestGetIt);

    Future<void> pumpLabelsListPage(
      WidgetTester tester, {
      bool settle = true,
      Map<String, int> usageCounts = const {},
    }) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            labelsRepositoryProvider.overrideWithValue(mockRepository),
            // Override the stream provider directly so private-label filtering
            // does not interfere with test data.
            labelsStreamProvider.overrideWith((ref) {
              return mockRepository.watchLabels();
            }),
            labelUsageStatsProvider.overrideWith(
              (ref) => Stream.value(usageCounts),
            ),
          ],
          child: const LabelsListPage(),
        ),
      );
      await tester.pump();
      if (settle) {
        await tester.pumpAndSettle();
      }
    }

    group('Loading and Error States', () {
      testWidgets('displays loading state initially', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => const Stream.empty(),
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              labelsRepositoryProvider.overrideWithValue(mockRepository),
              labelUsageStatsProvider.overrideWith(
                (ref) => const Stream.empty(),
              ),
            ],
            child: const LabelsListPage(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('displays error state when stream errors', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.error(Exception('Test error')),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.textContaining('Test error'), findsOneWidget);
      });
    });

    group('Empty State', () {
      testWidgets('displays empty state when no labels', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.label_outline), findsOneWidget);
      });
    });

    group('Label List Display', () {
      testWidgets('uses DesignSystemListItem for label rows', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemListItem), findsOneWidget);
        expect(find.text('Bug'), findsOneWidget);
      });

      testWidgets('displays labels in alphabetical order', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Zebra'),
          LabelTestUtils.createTestLabel(name: 'Alpha'),
          LabelTestUtils.createTestLabel(name: 'Beta'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final items = find.byType(DesignSystemListItem);
        expect(items, findsNWidgets(3));

        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.title, 'Alpha');
        expect(second.title, 'Beta');
        expect(third.title, 'Zebra');
      });

      testWidgets('shows description as subtitle when present', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(
            name: 'Important',
            description: 'High priority items',
          ),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.text('High priority items'), findsOneWidget);
      });

      testWidgets('shows usage count as subtitle when no description', (
        tester,
      ) async {
        const labelId = 'label-123';
        final labels = [
          LabelTestUtils.createTestLabel(id: labelId, name: 'Plain'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(
          tester,
          usageCounts: {labelId: 5},
        );

        expect(find.text('Used on 5 tasks'), findsOneWidget);
      });

      testWidgets('shows chevron trailing icon', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Test'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      });

      testWidgets('shows lock icon for private labels', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Secret', private: true),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      });

      testWidgets('hides lock icon for public labels', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Public'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byIcon(Icons.lock_outline), findsNothing);
      });

      testWidgets('shows dividers between items but not after last', (
        tester,
      ) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'A'),
          LabelTestUtils.createTestLabel(name: 'B'),
          LabelTestUtils.createTestLabel(name: 'C'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final items = find.byType(DesignSystemListItem);
        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        final third = tester.widget<DesignSystemListItem>(items.at(2));

        expect(first.showDivider, isTrue);
        expect(second.showDivider, isTrue);
        expect(third.showDivider, isFalse);
      });

      testWidgets('renders items inside DesignSystemGroupedList', (
        tester,
      ) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Test'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemGroupedList), findsOneWidget);
      });

      testWidgets('DesignSystemListItem is tappable', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Clickable'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        final item = tester.widget<DesignSystemListItem>(
          find.byType(DesignSystemListItem),
        );
        expect(item.onTap, isNotNull);
      });
    });

    group('Search and Filter', () {
      testWidgets('filters labels by name', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug'),
          LabelTestUtils.createTestLabel(name: 'Feature'),
          LabelTestUtils.createTestLabel(name: 'Bugfix'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(DesignSystemListItem), findsNWidgets(3));

        await tester.enterText(find.byType(TextField), 'Bug');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsNWidgets(2));

        final items = find.byType(DesignSystemListItem);
        final first = tester.widget<DesignSystemListItem>(items.at(0));
        final second = tester.widget<DesignSystemListItem>(items.at(1));
        expect(first.title, 'Bug');
        expect(second.title, 'Bugfix');
      });

      testWidgets('filters labels by description', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(
            name: 'Alpha',
            description: 'Tracks regressions',
          ),
          LabelTestUtils.createTestLabel(
            name: 'Beta',
            description: 'General tasks',
          ),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        await tester.enterText(find.byType(TextField), 'regression');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsOneWidget);
        expect(find.text('Alpha'), findsOneWidget);
      });

      testWidgets('shows no-match state with create button', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Bug'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        await tester.enterText(find.byType(TextField), 'zzz');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsNothing);
        expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);
      });

      testWidgets('search is case insensitive', (tester) async {
        final labels = [
          LabelTestUtils.createTestLabel(name: 'Important'),
        ];

        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value(labels),
        );

        await pumpLabelsListPage(tester);

        await tester.enterText(find.byType(TextField), 'IMPORT');
        await tester.pumpAndSettle();

        expect(find.byType(DesignSystemListItem), findsOneWidget);
      });
    });

    group('Layout', () {
      testWidgets('uses CustomScrollView', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(CustomScrollView), findsOneWidget);
      });

      testWidgets('shows FAB for creating labels', (tester) async {
        when(() => mockRepository.watchLabels()).thenAnswer(
          (_) => Stream.value([]),
        );

        await pumpLabelsListPage(tester);

        expect(find.byType(FloatingActionButton), findsOneWidget);
      });
    });
  });
}
