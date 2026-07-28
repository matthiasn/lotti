import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/celebration/completion_burst.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_ceremony_stages.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  // Matrix SAS verification shows seven emoji.
  final emojis = List.generate(
    7,
    (index) => FakeKeyVerificationEmoji('🐧', 'penguin$index'),
  );

  group('VerificationCeremonyHeader', () {
    testWidgets('names the device with its account and session in mono', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const VerificationCeremonyHeader(
            deviceName: 'Pixel 9 Pro',
            userId: '@alice:example.com',
            deviceId: 'DEVICE1',
          ),
        ),
      );

      expect(find.text('Pixel 9 Pro'), findsOneWidget);
      final meta = tester.widget<Text>(
        find.text('@alice:example.com · DEVICE1'),
      );
      // Compare-me identifiers, not prose.
      expect(meta.style?.fontFamily, 'Inconsolata');
    });

    testWidgets('omits the meta line when nothing can be resolved', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const VerificationCeremonyHeader(deviceName: 'Pixel 9 Pro'),
        ),
      );

      expect(find.text('Pixel 9 Pro'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });
  });

  group('VerificationEmojiStage', () {
    Future<void> pumpStage(
      WidgetTester tester, {
      bool awaiting = false,
      VoidCallback? onAccept,
      VoidCallback? onCancel,
    }) => tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        SingleChildScrollView(
          child: VerificationEmojiStage(
            emojis: emojis,
            awaitingOtherDevice: awaiting,
            onAccept: onAccept ?? () {},
            onCancel: onCancel ?? () {},
          ),
        ),
      ),
    );

    testWidgets('asks the literal question over the grid', (tester) async {
      await pumpStage(tester);

      final context = tester.element(find.byType(VerificationEmojiStage));
      expect(
        find.text(context.messages.syncVerifyPromptLine1),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncVerifyPromptQuestion),
        findsOneWidget,
      );
    });

    testWidgets('renders all seven emoji with their word labels', (
      tester,
    ) async {
      // The labels are part of the comparison: two similar glyphs on two
      // screens are disambiguated by the word beneath them.
      await pumpStage(tester);

      expect(find.text('🐧'), findsNWidgets(7));
      for (var i = 0; i < 7; i++) {
        expect(find.text('penguin$i'), findsOneWidget);
      }
    });

    testWidgets('long labels wrap instead of ellipsizing away the word', (
      tester,
    ) async {
      // The word is the textual disambiguation the security comparison
      // relies on; an ellipsized label defeats exactly that. Narrow sheet,
      // long SAS name ("Paperclip" is real; longer exist in translations).
      tester.view
        ..physicalSize = const Size(320, 1600)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: VerificationEmojiGrid(
              emojis: [
                FakeKeyVerificationEmoji('📎', 'Büroklammer'),
                ...emojis.skip(1),
              ],
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'no overflow');
      final label = tester.widget<Text>(find.text('Büroklammer'));
      expect(label.maxLines, isNull);
      expect(label.overflow, isNot(TextOverflow.ellipsis));
    });

    testWidgets('the decision pair states what each choice means', (
      tester,
    ) async {
      var accepted = 0;
      var cancelled = 0;
      await pumpStage(
        tester,
        onAccept: () => accepted++,
        onCancel: () => cancelled++,
      );

      final context = tester.element(find.byType(VerificationEmojiStage));
      await tester.ensureVisible(
        find.text(context.messages.syncVerifyTheyMatch),
      );
      await tester.tap(find.text(context.messages.syncVerifyTheyMatch));
      expect(accepted, 1);

      await tester.ensureVisible(
        find.text(context.messages.syncVerifyTheyDiffer),
      );
      await tester.tap(find.text(context.messages.syncVerifyTheyDiffer));
      expect(cancelled, 1);
    });

    testWidgets('waits on the peer with the accept disabled', (tester) async {
      var accepted = 0;
      await pumpStage(tester, awaiting: true, onAccept: () => accepted++);

      final context = tester.element(find.byType(VerificationEmojiStage));
      final accept = tester.widget<DesignSystemButton>(
        find.widgetWithText(
          DesignSystemButton,
          context.messages.settingsMatrixContinueVerificationLabel,
        ),
      );
      expect(accept.onPressed, isNull);
      expect(accepted, 0);
    });
  });

  group('VerificationSuccessStage', () {
    testWidgets('celebrates the trust property and confirms out', (
      tester,
    ) async {
      var confirmed = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: VerificationSuccessStage(onConfirm: () => confirmed++),
          ),
        ),
      );
      await tester.pump();

      final context = tester.element(find.byType(VerificationSuccessStage));
      expect(
        find.text(context.messages.syncVerifiedCelebrationTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.syncVerifiedCelebrationBody),
        findsOneWidget,
      );
      // The journey's motif closes: the gap between the machines is now a
      // solid line.
      final motif = tester.widget<SyncDevicePairMotif>(
        find.byType(SyncDevicePairMotif),
      );
      expect(motif.state, SyncDevicePairMotifState.linked);

      await tester.ensureVisible(
        find.text(context.messages.settingsMatrixVerificationSuccessConfirm),
      );
      await tester.tap(
        find.text(context.messages.settingsMatrixVerificationSuccessConfirm),
      );
      expect(confirmed, 1);

      // Drain the celebration burst so no ticker outlives the test.
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('honours the celebration master switch', (tester) async {
      // Reduced motion is the OS's veto; the in-app celebration switch is
      // the user's. Both must silence the burst.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: VerificationSuccessStage(onConfirm: () {}),
          ),
          overrides: [
            celebrationPreferencesProvider.overrideWithValue(
              const CelebrationPreferences.allEnabled().copyWith(
                enabled: false,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CompletionBurst), findsNothing);
      // The stage itself still renders — only the burst is suppressed.
      expect(
        find.byKey(const Key('verification_success_stage')),
        findsOneWidget,
      );
    });

    testWidgets('fires the burst when celebrations are on', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          SingleChildScrollView(
            child: VerificationSuccessStage(onConfirm: () {}),
          ),
          overrides: [
            celebrationPreferencesProvider.overrideWithValue(
              const CelebrationPreferences.allEnabled(),
            ),
          ],
        ),
      );
      // Two frames to insert the overlay entry, then advance into the
      // burst's visible window (it paints from ~12% of its 1400ms run).
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CompletionBurst), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('VerificationCancelledStage', () {
    testWidgets('offers exactly one way out', (tester) async {
      var confirmed = 0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          VerificationCancelledStage(
            confirmKey: const Key('cancelled_confirm'),
            onConfirm: () => confirmed++,
          ),
        ),
      );

      final context = tester.element(find.byType(VerificationCancelledStage));
      expect(
        find.text(context.messages.settingsMatrixVerificationCancelledLabel),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('cancelled_confirm')));
      expect(confirmed, 1);
    });
  });
}
