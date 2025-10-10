import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix.dart';
import 'package:lotti/features/sync/ui/matrix_settings_modal.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';
import '../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();

    // Default stubs
    when(() => mockMatrixService.isLoggedIn()).thenReturn(false);
    when(() => mockMatrixService.logout()).thenAnswer((_) async {});
  });

  group('MatrixSettingsCard', () {
    testWidgets('displays correct title and subtitle', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
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
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
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
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      // Verify the card rendered successfully
      expect(find.byType(MatrixSettingsCard), findsOneWidget);
    });

    testWidgets('starts from login page when user is logged out',
        (tester) async {
      when(() => mockMatrixService.isLoggedIn()).thenReturn(false);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      final element =
          tester.element(find.byType(MatrixSettingsCard)) as StatefulElement;
      final handle =
          (element.state as MatrixSettingsCardStateAccess).testHandle;
      handle.pageIndexNotifier.value = 5;
      handle.updatePageIndex();

      expect(handle.pageIndexNotifier.value, 0);
    });

    testWidgets('jumps to logged in page when user is already authenticated',
        (tester) async {
      when(() => mockMatrixService.isLoggedIn()).thenReturn(true);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const MatrixSettingsCard(),
          overrides: [
            matrixServiceProvider.overrideWithValue(mockMatrixService),
          ],
        ),
      );

      final element =
          tester.element(find.byType(MatrixSettingsCard)) as StatefulElement;
      final handle =
          (element.state as MatrixSettingsCardStateAccess).testHandle;
      handle.pageIndexNotifier.value = 0;
      handle.updatePageIndex();

      expect(handle.pageIndexNotifier.value, 1);
    });
  });
}
