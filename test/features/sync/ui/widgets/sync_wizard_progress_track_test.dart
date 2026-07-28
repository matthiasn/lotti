import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/sync_wizard_progress_track.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpTrack(WidgetTester tester, SyncWizardStep active) =>
      tester.pumpWidget(
        makeTestableWidget(SyncWizardProgressTrack(active: active)),
      );

  /// The three segment fills, in station order. Each segment is a
  /// pill-radius DecoratedBox above its label.
  List<Color> segmentFills(WidgetTester tester) {
    final tokens = tester
        .element(find.byType(SyncWizardProgressTrack))
        .designTokens;
    return tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(SyncWizardProgressTrack),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .where(
          (d) =>
              d.borderRadius == BorderRadius.circular(tokens.radii.badgesPills),
        )
        .map((d) => d.color!)
        .toList();
  }

  group('SyncWizardProgressTrack', () {
    testWidgets('names all three stations', (tester) async {
      await pumpTrack(tester, SyncWizardStep.getCode);

      final context = tester.element(find.byType(SyncWizardProgressTrack));
      expect(find.text(context.messages.syncWizardStepGetCode), findsOneWidget);
      expect(find.text(context.messages.syncWizardStepCheck), findsOneWidget);
      expect(
        find.text(context.messages.syncWizardStepConnect),
        findsOneWidget,
      );
    });

    testWidgets('fills the active station with the accent', (tester) async {
      await pumpTrack(tester, SyncWizardStep.getCode);

      final tokens = tester
          .element(find.byType(SyncWizardProgressTrack))
          .designTokens;
      final fills = segmentFills(tester);
      expect(fills, hasLength(3));
      expect(fills[0], tokens.colors.interactive.enabled);
      // Upcoming stations carry the neutral track, not a second accent.
      expect(fills[1], tokens.colors.surface.hover);
      expect(fills[2], tokens.colors.surface.hover);
    });

    testWidgets('fades stations already passed instead of dropping them', (
      tester,
    ) async {
      await pumpTrack(tester, SyncWizardStep.connect);

      final tokens = tester
          .element(find.byType(SyncWizardProgressTrack))
          .designTokens;
      final fills = segmentFills(tester);
      // The passed stations keep the accent hue, faded — so the track reads
      // as one line filling up, with exactly one full-strength station.
      expect(
        fills[0],
        tokens.colors.interactive.enabled.withValues(alpha: 0.4),
      );
      expect(
        fills[1],
        tokens.colors.interactive.enabled.withValues(alpha: 0.4),
      );
      expect(fills[2], tokens.colors.interactive.enabled);
    });

    testWidgets('announces the current position to assistive technology', (
      tester,
    ) async {
      // The position lives in paint — fill and weight — which a screen
      // reader cannot perceive. Without this node it would announce three
      // equal captions and no "which step am I on".
      final handle = tester.ensureSemantics();
      addTearDown(handle.dispose);
      await pumpTrack(tester, SyncWizardStep.check);

      final context = tester.element(find.byType(SyncWizardProgressTrack));
      expect(
        find.bySemanticsLabel(
          context.messages.syncWizardStepStatus(
            2,
            context.messages.syncWizardStepCheck,
          ),
        ),
        findsOneWidget,
      );
      // The three raw captions are excluded: they carry no position and
      // would bury the one node that does.
      expect(
        find.bySemanticsLabel(context.messages.syncWizardStepGetCode),
        findsNothing,
      );
    });

    testWidgets('gives only the active label full emphasis', (tester) async {
      await pumpTrack(tester, SyncWizardStep.check);

      final context = tester.element(find.byType(SyncWizardProgressTrack));
      final tokens = context.designTokens;
      final active = tester.widget<Text>(
        find.text(context.messages.syncWizardStepCheck),
      );
      final upcoming = tester.widget<Text>(
        find.text(context.messages.syncWizardStepConnect),
      );

      expect(active.style?.color, tokens.colors.text.highEmphasis);
      expect(active.style?.fontWeight, tokens.typography.weight.semiBold);
      expect(upcoming.style?.color, tokens.colors.text.lowEmphasis);
    });
  });
}
