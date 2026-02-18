import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/measurement_summary.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/health_import.dart';
import 'package:lotti/services/entities_cache_service.dart';
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

    testWidgets('displays formatted measurement value with unit',
        (tester) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableCoverage.id),
      ).thenAnswer((_) => measurableCoverage);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasuredCoverageEntry),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Coverage: 55 %'), findsOneWidget);
    });

    testWidgets('displays TextViewerWidget when entryText is present',
        (tester) async {
      when(
        () => mockEntitiesCacheService.getDataTypeById(measurableCoverage.id),
      ).thenAnswer((_) => measurableCoverage);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MeasurementSummary(testMeasuredCoverageEntry),
        ),
      );
      await tester.pumpAndSettle();

      // testMeasuredCoverageEntry has entryText, so TextViewerWidget should
      // render it (via QuillEditor, not as plain Text widget)
      expect(find.byType(TextViewerWidget), findsOneWidget);
    });

    testWidgets('renders SizedBox.shrink when dataType is null',
        (tester) async {
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
      expect(find.text('Coverage: 55 %'), findsNothing);
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
      expect(find.text('Coverage: 55 %'), findsOneWidget);
      // But TextViewerWidget should not appear
      expect(find.byType(TextViewerWidget), findsNothing);
    });
  });
}
