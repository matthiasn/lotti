import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/diagnostic_info_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../widget_test_utils.dart';

class MockMatrixService extends Mock implements MatrixService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockMatrixService mockMatrixService;

  setUp(() {
    mockMatrixService = MockMatrixService();
    when(() => mockMatrixService.getDiagnosticInfo()).thenAnswer(
      (_) async => <String, dynamic>{
        'deviceId': 'TESTDEVICE',
        'isLoggedIn': true,
        'userId': '@alice:example.com',
      },
    );
  });

  testWidgets('renders button with correct label', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const DiagnosticInfoButton(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(DiagnosticInfoButton));
    expect(
      find.text(context.messages.settingsMatrixDiagnosticShowButton),
      findsOneWidget,
    );
  });

  testWidgets('tapping button shows dialog with diagnostic JSON',
      (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const DiagnosticInfoButton(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(DiagnosticInfoButton));
    await tester.tap(
      find.text(context.messages.settingsMatrixDiagnosticShowButton),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(context.messages.settingsMatrixDiagnosticDialogTitle),
      findsOneWidget,
    );
    expect(find.textContaining('TESTDEVICE'), findsOneWidget);
    expect(find.textContaining('@alice:example.com'), findsOneWidget);
  });

  testWidgets('copy button copies JSON and shows snackbar', (tester) async {
    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          clipboardText = args['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const DiagnosticInfoButton(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(DiagnosticInfoButton));
    await tester.tap(
      find.text(context.messages.settingsMatrixDiagnosticShowButton),
    );
    await tester.pumpAndSettle();

    // Tap the copy button
    await tester.tap(
      find.text(context.messages.settingsMatrixDiagnosticCopyButton),
    );
    await tester.pumpAndSettle();

    expect(clipboardText, isNotNull);
    expect(clipboardText, contains('TESTDEVICE'));

    // Dialog should be dismissed and snackbar shown
    expect(find.byType(AlertDialog), findsNothing);
    expect(
      find.text(context.messages.settingsMatrixDiagnosticCopied),
      findsOneWidget,
    );
  });

  testWidgets('close button dismisses dialog', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const DiagnosticInfoButton(),
        overrides: [
          matrixServiceProvider.overrideWithValue(mockMatrixService),
        ],
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(DiagnosticInfoButton));
    await tester.tap(
      find.text(context.messages.settingsMatrixDiagnosticShowButton),
    );
    await tester.pumpAndSettle();

    // Dialog should be visible
    expect(find.byType(AlertDialog), findsOneWidget);

    // Tap the close button
    await tester.tap(
      find.text(context.messages.tasksLabelsDialogClose),
    );
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.byType(AlertDialog), findsNothing);
  });
}
