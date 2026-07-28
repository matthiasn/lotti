import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_ceremony_stages.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  final emojis = List.generate(
    8,
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

    testWidgets('renders all eight emoji with their word labels', (
      tester,
    ) async {
      // The labels are part of the comparison: two similar glyphs on two
      // screens are disambiguated by the word beneath them.
      await pumpStage(tester);

      expect(find.text('🐧'), findsNWidgets(8));
      for (var i = 0; i < 8; i++) {
        expect(find.text('penguin$i'), findsOneWidget);
      }
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
