import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _LoadingMatrixStatsController extends MatrixStatsController {
  @override
  Future<MatrixStats> build() async {
    // Never completes to force loading state
    return Completer<MatrixStats>().future;
  }
}

class _ImmediateMatrixStatsController extends MatrixStatsController {
  @override
  Future<MatrixStats> build() async {
    return MatrixStats(sentCount: 0, messageCounts: <String, int>{});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SyncStatsPage', () {
    late MockJournalDb mockJournalDb;
    late MatrixService mockMatrixService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      // Gate enabled
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));
      getIt.registerSingleton<JournalDb>(mockJournalDb);
      mockMatrixService = MockMatrixService();
      when(() => mockMatrixService.getV2Metrics())
          .thenAnswer((_) async => null);
      when(() => mockMatrixService.getSyncDiagnosticsText())
          .thenAnswer((_) async => 'ok');
    });

    tearDown(getIt.reset);

    testWidgets('shows large spinner while loading', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SyncStatsPage(),
          overrides: [
            matrixStatsControllerProvider
                .overrideWith(_LoadingMatrixStatsController.new),
          ],
        ),
      );

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // Let entrance animations complete to avoid pending timers, but keep
      // stats future unresolved so spinner stays.
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('shows stats card when data available', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SyncStatsPage(),
          overrides: [
            matrixStatsControllerProvider
                .overrideWith(_ImmediateMatrixStatsController.new),
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pumpAndSettle();
      // Title and card content present
      expect(find.text('Matrix Stats'), findsWidgets);
    });
  });
}
