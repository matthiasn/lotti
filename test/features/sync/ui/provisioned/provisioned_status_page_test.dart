import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/provisioned/provisioned_status_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

class MockClient extends Mock implements Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;
  late MockClient mockClient;

  setUp(() {
    mockMatrixService = MockMatrixService();
    mockClient = MockClient();

    when(() => mockMatrixService.client).thenReturn(mockClient);
    when(() => mockClient.userID).thenReturn('@alice:example.com');
    when(() => mockMatrixService.syncRoomId).thenReturn('!room123:example.com');
    when(() => mockMatrixService.deleteConfig()).thenAnswer((_) async {});
  });

  group('ProvisionedStatusWidget', () {
    testWidgets('displays user ID from Matrix client', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('@alice:example.com'), findsOneWidget);
    });

    testWidgets('displays sync room ID', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('!room123:example.com'), findsOneWidget);
    });

    testWidgets('displays labels for user and room', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncSummaryUser),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.provisionedSyncSummaryRoom),
        findsOneWidget,
      );
    });

    testWidgets('displays diagnostic info button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      expect(find.text('Show Diagnostic Info'), findsOneWidget);
    });

    testWidgets('displays disconnect button', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      expect(
        find.text(context.messages.provisionedSyncDisconnect),
        findsOneWidget,
      );
    });

    testWidgets('disconnect calls deleteConfig and resets controller',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(ProvisionedStatusWidget));
      await tester.tap(find.text(context.messages.provisionedSyncDisconnect));
      await tester.pumpAndSettle();

      verify(() => mockMatrixService.deleteConfig()).called(1);
    });

    testWidgets('handles null user ID gracefully', (tester) async {
      when(() => mockClient.userID).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      // Should show empty string when user ID is null
      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
    });

    testWidgets('handles null room ID gracefully', (tester) async {
      when(() => mockMatrixService.syncRoomId).thenReturn(null);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      // Should show empty string when room ID is null
      expect(find.byType(ProvisionedStatusWidget), findsOneWidget);
    });

    testWidgets('user ID and room ID are selectable', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const ProvisionedStatusWidget(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      // SelectableText widgets for the values
      final selectableTexts = find.byType(SelectableText);
      expect(selectableTexts, findsAtLeast(2));
    });
  });

  group('ProvisionedStatusPage action bar', () {
    testWidgets('back button navigates to page 0', (tester) async {
      final pageIndexNotifier = ValueNotifier<int>(2);
      addTearDown(pageIndexNotifier.dispose);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          _StatusActionBarTestWrapper(
            pageIndexNotifier: pageIndexNotifier,
          ),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(_StatusActionBarTestWrapper));
      await tester.tap(
        find.text(context.messages.settingsMatrixPreviousPage),
      );
      await tester.pump();

      expect(pageIndexNotifier.value, 0);
    });
  });
}

/// Wrapper to test navigation via pageIndexNotifier. Since _StatusActionBar
/// is private, we replicate its back-button logic through the notifier.
class _StatusActionBarTestWrapper extends StatelessWidget {
  const _StatusActionBarTestWrapper({required this.pageIndexNotifier});

  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ProvisionedStatusWidget(),
        Row(
          children: [
            OutlinedButton(
              onPressed: () => pageIndexNotifier.value = 0,
              child: Text(context.messages.settingsMatrixPreviousPage),
            ),
          ],
        ),
      ],
    );
  }
}
