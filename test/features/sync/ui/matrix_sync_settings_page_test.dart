import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/features/sync/ui/matrix_sync_settings_page.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/consts.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixSyncSettingsPage', () {
    late MockJournalDb mockJournalDb;
    late MockMatrixService mockMatrixService;

    setUp(() {
      mockJournalDb = MockJournalDb();
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(true));

      mockMatrixService = MockMatrixService();
      when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
      when(() => mockMatrixService.logout()).thenAnswer((_) async {});

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService());
    });

    tearDown(getIt.reset);

    testWidgets('renders matrix setup and maintenance cards', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSyncSettingsPage(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MatrixSyncSettingsPage));
      expect(find.byType(MatrixSettingsCard), findsOneWidget);
      expect(
        find.text(context.messages.settingsMatrixMaintenanceTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.settingsMatrixMaintenanceSubtitle),
        findsOneWidget,
      );
    });

    testWidgets('hides content when Matrix flag disabled', (tester) async {
      await getIt.reset();
      mockJournalDb = MockJournalDb();
      when(() => mockJournalDb.watchConfigFlag(enableMatrixFlag))
          .thenAnswer((_) => Stream<bool>.value(false));

      getIt
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<UserActivityService>(UserActivityService());

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSyncSettingsPage(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      await tester.pump();

      expect(find.byType(MatrixSettingsCard), findsNothing);
      final scaffoldContext = tester.element(find.byType(Scaffold));
      expect(
        find.text(scaffoldContext.messages.settingsMatrixMaintenanceTitle),
        findsNothing,
      );
    });
  });
}
