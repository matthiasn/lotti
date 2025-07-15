import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockLoggingService extends Mock implements LoggingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockJournalDb mockJournalDb;
  late MockLoggingService mockLoggingService;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockJournalDb = MockJournalDb();
    mockLoggingService = MockLoggingService();

    // Register mocks with GetIt
    getIt
      ..registerSingleton<MatrixService>(mockMatrixService)
      ..registerSingleton<JournalDb>(mockJournalDb)
      ..registerSingleton<LoggingService>(mockLoggingService);

    // Default stubs
    when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
    when(() => mockMatrixService.logout()).thenAnswer((_) async {});

    when(() => mockJournalDb.watchConfigFlag(any()))
        .thenAnswer((_) => Stream.value(true));
  });

  tearDown(getIt.reset);

  group('MatrixSettingsCard', () {
    testWidgets('displays correct title and subtitle', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSettingsCard(),
        ),
      );

      final context = tester.element(find.byType(MatrixSettingsCard));

      expect(find.text(context.messages.settingsMatrixTitle), findsOneWidget);
      expect(find.text('Configure end-to-end encrypted sync'), findsOneWidget);
      // The icon appears multiple times due to animation states
      expect(find.byIcon(Icons.sync), findsWidgets);
    });

    testWidgets('card is tappable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSettingsCard(),
        ),
      );

      // Verify the card is present and tappable
      final card = find.byType(MatrixSettingsCard);
      expect(card, findsOneWidget);

      // The card uses AnimatedModernSettingsCardWithIcon which has a GestureDetector
      expect(
          find.descendant(
            of: card,
            matching: find.byType(GestureDetector),
          ),
          findsWidgets);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSettingsCard(),
        ),
      );

      // Verify the card rendered successfully
      expect(find.byType(MatrixSettingsCard), findsOneWidget);
    });
  });
}
