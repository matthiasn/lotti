import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/features/sync/ui/deep_backfill_modal.dart';
import 'package:lotti/features/sync/ui/deep_backfill_progress.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

/// Records whether the modal started a round, and holds it open so the
/// progress page stays up while the test looks at it.
class _FakeDeepBackfillController extends DeepBackfillController {
  int rounds = 0;
  final Completer<void> gate = Completer<void>();

  @override
  Future<void> runRound() async {
    rounds++;
    state = const DeepBackfillState(
      isRunning: true,
      advertised: 1,
      total: 4,
    );
    await gate.future;
  }
}

void main() {
  late _FakeDeepBackfillController controller;

  Widget trigger() => Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => DeepBackfillModal.show(context),
      child: const Text('Show'),
    ),
  );

  Future<BuildContext> open(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        trigger(),
        overrides: [
          deepBackfillControllerProvider.overrideWith(() => controller),
        ],
      ),
    );
    final context = tester.element(find.text('Show'));
    await tester.tap(find.text('Show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return context;
  }

  setUp(() => controller = _FakeDeepBackfillController());

  testWidgets('asks before starting and starts nothing on cancel', (
    tester,
  ) async {
    final context = await open(tester);

    expect(
      find.text(context.messages.maintenanceDeepBackfillMessage),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.rounds, 0);
  });

  testWidgets('confirming runs a round and shows its progress', (
    tester,
  ) async {
    final context = await open(tester);
    final confirm = find.widgetWithText(
      DesignSystemButton,
      context.messages.maintenanceDeepBackfillConfirm,
    );
    await tester.ensureVisible(confirm);
    await tester.pump();
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.rounds, 1);
    expect(find.byType(DeepBackfillProgress), findsOneWidget);
    expect(find.text('1 of 4 records listed'), findsOneWidget);

    controller.gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });
}
