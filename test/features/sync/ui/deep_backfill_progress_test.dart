import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/state/deep_backfill_controller.dart';
import 'package:lotti/features/sync/ui/deep_backfill_progress.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, DeepBackfillState state) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Center(
          child: SizedBox(
            width: 400,
            child: DeepBackfillProgress(state: state),
          ),
        ),
        theme: DesignSystemTheme.light(),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows how many records of the round are listed', (
    tester,
  ) async {
    await pump(
      tester,
      const DeepBackfillState(isRunning: true, advertised: 250, total: 1000),
    );

    final bar = tester.widget<DesignSystemProgressBar>(
      find.byType(DesignSystemProgressBar),
    );
    expect(bar.value, 0.25);
    expect(bar.progressText, '25%');
    expect(find.text('250 of 1000 records listed'), findsOneWidget);
    expect(find.byIcon(LottiIcons.confirmCircled), findsNothing);
  });

  testWidgets('shows the records listed for the other devices when done', (
    tester,
  ) async {
    await pump(
      tester,
      const DeepBackfillState(isDone: true, advertised: 42, total: 42),
    );

    expect(find.byIcon(LottiIcons.confirmCircled), findsOneWidget);
    expect(
      find.text('42 records listed for your other devices'),
      findsOneWidget,
    );
    expect(find.byType(DesignSystemProgressBar), findsNothing);
  });

  testWidgets('shows the error that stopped the round', (tester) async {
    await pump(tester, const DeepBackfillState(error: 'Bad state: no host'));

    expect(find.byIcon(LottiIcons.error), findsOneWidget);
    expect(find.text('Bad state: no host'), findsOneWidget);
    expect(find.byType(DesignSystemProgressBar), findsNothing);
  });

  group('DeepBackfillState.progress', () {
    test('is the share listed, and 1 for a finished empty round', () {
      expect(
        const DeepBackfillState(advertised: 3, total: 4).progress,
        0.75,
      );
      expect(const DeepBackfillState().progress, 0);
      expect(const DeepBackfillState(isDone: true).progress, 1);
    });
  });
}
