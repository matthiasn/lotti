import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/sync_stats_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _ImmediateMatrixStatsController extends MatrixStatsController {
  @override
  Future<MatrixStats> build() async {
    return const MatrixStats(sentCount: 0, messageCounts: <String, int>{});
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
      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService());
      mockMatrixService = MockMatrixService();
      when(() => mockMatrixService.getSyncMetrics())
          .thenAnswer((_) async => null);
      when(() => mockMatrixService.getSyncDiagnosticsText())
          .thenAnswer((_) async => 'ok');
    });

    tearDown(getIt.reset);

    testWidgets('gates page when feature disabled', (tester) async {
      // Feature flag off
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(false));
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SyncStatsPage(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();
      // No Matrix Stats title rendered when gated.
      expect(find.text('Matrix Stats'), findsNothing);
    });

    testWidgets('renders page without page-level loader', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SyncStatsPage(),
          overrides: [
            // Provide matrixService to avoid provider errors; page does not
            // watch stats provider anymore.
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();
      expect(find.text('Matrix Stats'), findsOneWidget);
      // Allow entrance animations to settle so no pending timers remain.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
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
      // Title and card content present (single title expected)
      expect(find.text('Matrix Stats'), findsOneWidget);
    });
  });
}
