import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../test_data/test_data.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  group('MeasurementSummary', () {
    late MockJournalDb mockJournalDb;
    late MockEntitiesCacheService mockEntitiesCacheService;
    late MockHealthImport mockHealthImport;

    setUp(() {
      mockJournalDb = MockJournalDb();
      mockEntitiesCacheService = MockEntitiesCacheService();
      mockHealthImport = MockHealthImport();

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<EntitiesCacheService>(mockEntitiesCacheService)
        ..registerSingleton<HealthImport>(mockHealthImport);
    });

    tearDown(getIt.reset);

    testWidgets('displays formatted measurement value with unit', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableCoverage.id),
      ).thenAnswer((_) => measurableCoverage);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasuredCoverageEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Coverage: 55%'), findsOneWidget);
    });

    testWidgets('a choice recording reads as name: choice title', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableHydration.id),
      ).thenAnswer((_) => measurableHydration);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasurementHydrationEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Hydration: Clear'), findsOneWidget);
      // Never the occurrence count that backs the value.
      expect(find.textContaining('Hydration: 1'), findsNothing);
    });

    testWidgets('a choice no longer on the definition reads as removed', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableHydration.id),
      ).thenAnswer((_) => measurableHydration);
      final orphan = testMeasurementHydrationEntry.copyWith(
        data: testMeasurementHydrationEntry.data.copyWith(choiceId: 'gone'),
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(MeasurementSummary(orphan)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Hydration: Removed choice'), findsOneWidget);
    });

    testWidgets('does not duplicate the note — summary shows only the value', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableCoverage.id),
      ).thenAnswer((_) => measurableCoverage);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasuredCoverageEntry),
        ),
      );
      await tester.pumpAndSettle();

      // Even though the entry has a note, the summary renders only the value
      // line: the note is shown once by the card's editor above the summary, so
      // the summary no longer repeats it via a TextViewerWidget.
      expect(find.byType(TextViewerWidget), findsNothing);
      expect(find.textContaining('Coverage: 55%'), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when dataType is null', (
      tester,
    ) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableCoverage.id),
      ).thenAnswer((_) => null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasuredCoverageEntry),
        ),
      );
      await tester.pumpAndSettle();

      // Should render nothing when dataType is null
      expect(find.textContaining('Coverage: 55%'), findsNothing);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('hides TextViewer when entryText is null', (tester) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableCoverage.id),
      ).thenAnswer((_) => measurableCoverage);

      final entryWithoutText = MeasurementEntry(
        meta: testMeasuredCoverageEntry.meta,
        data: testMeasuredCoverageEntry.data,
      );

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(entryWithoutText),
        ),
      );
      await tester.pumpAndSettle();

      // Value should still display
      expect(find.textContaining('Coverage: 55%'), findsOneWidget);
      // But TextViewerWidget should not appear
      expect(find.byType(TextViewerWidget), findsNothing);
    });
  });
}
