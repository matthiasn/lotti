import 'dart:io';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/profiles/model/profile.dart';
import 'package:lotti/features/profiles/model/profile_context.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_counts.dart';
import 'package:lotti/features/sync/state/outbox_state_controller.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:material_ui/material_ui.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../mocks/sync_config_test_mocks.dart';
import '../../../../../widget_test_utils.dart';

void main() {
  /// Overrides putting sync online with the given queue depths.
  List<Override> queues({
    required int incoming,
    required int outgoing,
    bool syncEnabled = true,
  }) => [
    journalDbProvider.overrideWithValue(
      mockJournalDbWithSyncFlag(enabled: syncEnabled),
    ),
    syncDatabaseProvider.overrideWithValue(mockSyncDatabaseWithCount(outgoing)),
    inboundQueueDepthProvider.overrideWith((_) => Stream<int>.value(incoming)),
  ];

  Future<void> pumpBadge(
    WidgetTester tester, {
    required int incoming,
    required int outgoing,
    bool syncEnabled = true,
    Widget Function(Widget child)? wrap,
  }) async {
    const counts = SyncQueueCounts();
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        wrap == null ? counts : wrap(counts),
        overrides: queues(
          incoming: incoming,
          outgoing: outgoing,
          syncEnabled: syncEnabled,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder countTexts() => find.descendant(
    of: find.byType(SyncQueueCounts),
    matching: find.byType(Text),
  );

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(SyncQueueCounts)).designTokens;

  group('SyncQueueCounts visibility', () {
    testWidgets('renders nothing when sync is disabled', (tester) async {
      await pumpBadge(
        tester,
        incoming: 6,
        outgoing: 9,
        syncEnabled: false,
      );

      expect(countTexts(), findsNothing);
    });

    testWidgets('renders nothing when both queues are empty', (tester) async {
      await pumpBadge(tester, incoming: 0, outgoing: 0);

      expect(countTexts(), findsNothing);
    });

    testWidgets('shows only the incoming count when nothing is outgoing', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 0);

      expect(countTexts(), findsOneWidget);
      expect(find.text('↓\u202F3'), findsOneWidget);
    });

    testWidgets('shows only the outgoing count when nothing is incoming', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 0, outgoing: 4);

      expect(countTexts(), findsOneWidget);
      expect(find.text('↑\u202F4'), findsOneWidget);
    });

    testWidgets('shows both directions when both queues have work', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 4);

      expect(countTexts(), findsNWidgets(2));
      expect(find.text('↓\u202F3'), findsOneWidget);
      expect(find.text('↑\u202F4'), findsOneWidget);
    });
  });

  group('SyncQueueCounts quiet presentation', () {
    testWidgets('draws no box around the counts', (tester) async {
      // The regression this change exists to prevent. The counts were pills
      // with an outline, which gave ambient queue depth the weight of a
      // status chip beside the row's actual navigation.
      await pumpBadge(tester, incoming: 3, outgoing: 4);

      expect(
        find.descendant(
          of: find.byType(SyncQueueCounts),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
    });

    testWidgets('inks the counts at low emphasis, below the row label', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 4);
      final tokens = tokensOf(tester);

      for (final text in tester.widgetList<Text>(countTexts())) {
        expect(text.style?.color, tokens.colors.text.lowEmphasis);
      }
      // Not merely "some dim colour" — specifically dimmer than the step it
      // used to sit at, which is the change being pinned.
      expect(
        tokens.colors.text.lowEmphasis,
        isNot(tokens.colors.text.mediumEmphasis),
      );
    });

    testWidgets('uses the caption type style rather than an ad hoc size', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 4);
      final caption = tokensOf(tester).typography.styles.others.caption;

      for (final text in tester.widgetList<Text>(countTexts())) {
        expect(text.style?.fontSize, caption.fontSize);
        expect(text.style?.fontWeight, caption.fontWeight);
      }
    });

    testWidgets('shapes both counts with tabular figures', (tester) async {
      // Without this a 9 → 10 → 99 transition re-widths the row on every
      // sync tick.
      await pumpBadge(tester, incoming: 3, outgoing: 4);

      for (final text in tester.widgetList<Text>(countTexts())) {
        expect(text.style?.fontFeatures, numericBadgeFontFeatures);
      }
    });

    testWidgets('separates the two directions by more than their inner gap', (
      tester,
    ) async {
      // With the outlines gone this gap is the only thing keeping the pair
      // from reading as one run of glyphs.
      await pumpBadge(tester, incoming: 3, outgoing: 4);
      final tokens = tokensOf(tester);

      final gap = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(SyncQueueCounts),
          matching: find.byType(SizedBox),
        ),
      );
      expect(gap.width, tokens.spacing.step3);
    });

    testWidgets('omits the separator when only one direction is shown', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 0);

      expect(
        find.descendant(
          of: find.byType(SyncQueueCounts),
          matching: find.byType(SizedBox),
        ),
        findsNothing,
      );
    });
  });

  group('SyncQueueCounts count formatting', () {
    testWidgets('renders large counts compactly rather than in full', (
      tester,
    ) async {
      // The uncapped form ('↓\u202F18342') is what let a busy queue take the
      // Settings label's width until the label wrapped into a column of
      // letters.
      await pumpBadge(tester, incoming: 18342, outgoing: 1204);

      expect(find.text('↓\u202F18K'), findsOneWidget);
      expect(find.text('↑\u202F1.2K'), findsOneWidget);
      expect(find.text('↓\u202F18342'), findsNothing);
    });

    testWidgets('sets the arrow beside the digit, not a word apart', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 4);

      // The ordinary-space forms are what this change replaced; if either
      // renders, the gap reverted.
      expect(find.text('↓ 3'), findsNothing);
      expect(find.text('↑ 4'), findsNothing);
    });
  });

  group('SyncQueueCounts accessibility', () {
    testWidgets('announces the exact figure, not the compacted one', (
      tester,
    ) async {
      // Compaction serves the row's width budget; a screen reader has no such
      // constraint and should hear the real figure.
      await pumpBadge(tester, incoming: 18342, outgoing: 1204);
      final context = tester.element(find.byType(SyncQueueCounts));
      final messages = context.messages;

      expect(
        find.bySemanticsLabel(messages.syncQueueIncomingSemanticLabel(18342)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(messages.syncQueueOutgoingSemanticLabel(1204)),
        findsOneWidget,
      );
    });

    testWidgets('names each direction so the arrows are not the only cue', (
      tester,
    ) async {
      await pumpBadge(tester, incoming: 3, outgoing: 4);
      final context = tester.element(find.byType(SyncQueueCounts));
      final messages = context.messages;

      expect(
        find.bySemanticsLabel(messages.syncQueueIncomingSemanticLabel(3)),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(messages.syncQueueOutgoingSemanticLabel(4)),
        findsOneWidget,
      );
    });

    testWidgets('does not also announce the compacted visible string', (
      tester,
    ) async {
      // The visible text is excluded from semantics, so a screen reader hears
      // "Inbox: 18342" rather than that plus a bare "↓ 18K".
      await pumpBadge(tester, incoming: 18342, outgoing: 1204);

      expect(find.bySemanticsLabel('↓\u202F18K'), findsNothing);
      expect(find.bySemanticsLabel('↑\u202F1.2K'), findsNothing);
    });
  });

  group('SyncQueueCounts layout under pressure', () {
    testWidgets('shares a too-narrow slot instead of overflowing it', (
      tester,
    ) async {
      // Six-figure queues in both directions on a 200 px rail is the case the
      // sidebar clamps. Both directions shorten together rather than one
      // winning the row and the other spilling out of it.
      await pumpBadge(
        tester,
        incoming: 999999,
        outgoing: 999999,
        wrap: (child) => SizedBox(width: 40, child: child),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps each count on one line', (tester) async {
      await pumpBadge(tester, incoming: 18342, outgoing: 1204);

      for (final text in tester.widgetList<Text>(countTexts())) {
        expect(text.maxLines, 1);
        expect(text.overflow, TextOverflow.ellipsis);
      }
    });

    testWidgets('takes only the width its counts need', (tester) async {
      // `mainAxisSize.min` is what lets the sidebar give the row's remaining
      // width to the Settings label rather than to empty trailing space.
      // `Align` hands the counts loose constraints, the way the sidebar row's
      // trailing slot does. A tight `SizedBox` would force it to 300 whatever
      // `mainAxisSize` said, and the assertion below would prove nothing.
      await pumpBadge(
        tester,
        incoming: 3,
        outgoing: 4,
        wrap: (child) => SizedBox(
          width: 300,
          child: Align(alignment: Alignment.centerLeft, child: child),
        ),
      );

      final row = tester.widget<Row>(
        find.descendant(
          of: find.byType(SyncQueueCounts),
          matching: find.byType(Row),
        ),
      );
      expect(row.mainAxisSize, MainAxisSize.min);
      expect(
        tester.getSize(find.byType(SyncQueueCounts)).width,
        lessThan(300),
      );
    });
  });

  group('SyncQueueCounts guest worlds', () {
    ProfileContext contextFor(ProfileType type) => ProfileContext.forProfile(
      profile: Profile(
        id: type == ProfileType.real ? Profile.realProfileId : 'g1',
        type: type,
        name: 'world',
        dirName: type == ProfileType.real ? '' : 'guest_profiles/g1',
        createdAt: DateTime(2026),
      ),
      root: Directory('/data/lotti'),
    );

    testWidgets('renders nothing even with the matrix flag on', (
      tester,
    ) async {
      // The dangerous shape, and the only one that actually exercises the
      // gate: a guest world whose journal db still carries the matrix flag,
      // so the connection state resolves *online* and the widget runs past
      // its early return. `matrixServiceProvider` is deliberately left
      // unoverridden here exactly as a guest world leaves it, so the real
      // `inboundQueueDepthProvider` is what gets reached. `inboundQueue` is
      // therefore NOT stubbed — stubbing it is what would hide the bug.
      //
      // Ungated, this renders the outgoing count beside Settings in a world
      // that has no sync at all, having resolved the Matrix stack to an
      // UnimplementedError on the way.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SyncQueueCounts(),
          overrides: [
            profileContextProvider.overrideWithValue(
              contextFor(ProfileType.guest),
            ),
            journalDbProvider.overrideWithValue(
              mockJournalDbWithSyncFlag(enabled: true),
            ),
            syncDatabaseProvider.overrideWithValue(
              mockSyncDatabaseWithCount(4),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(countTexts(), findsNothing);
      expect(find.textContaining('4'), findsNothing);
    });

    testWidgets('still renders for a real profile under the same wiring', (
      tester,
    ) async {
      // The mirror of the case above: proves the gate keys on the world's
      // capability rather than the widget simply never rendering.
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const SyncQueueCounts(),
          overrides: [
            profileContextProvider.overrideWithValue(
              contextFor(ProfileType.real),
            ),
            ...queues(incoming: 3, outgoing: 4),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(countTexts(), findsNWidgets(2));
    });
  });

  group('SyncQueueCounts semantic labels resolve in every shipped locale', () {
    // The labels are the only thing a screen reader gets — the visible string
    // is excluded from semantics — so a locale that silently failed to
    // resolve them would leave those users with nothing. `en_GB` is the case
    // worth naming: it carries no entry of its own, by the convention that it
    // gets one only where the spelling differs from US English, and instead
    // inherits from `AppLocalizationsEn`. This asserts that inheritance
    // actually resolves rather than assuming it.
    testWidgets('every supported locale returns a label carrying the count', (
      tester,
    ) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final messages = await AppLocalizations.delegate.load(locale);
        final incoming = messages.syncQueueIncomingSemanticLabel(18342);
        final outgoing = messages.syncQueueOutgoingSemanticLabel(1204);

        for (final (label, count) in [
          (incoming, '18342'),
          (outgoing, '1204'),
        ]) {
          expect(
            label,
            contains(count),
            reason: '$locale dropped the count from its semantic label',
          );
          expect(
            label,
            isNot(contains('{count}')),
            reason: '$locale left the placeholder unsubstituted',
          );
          expect(
            label.trim(),
            isNot(count),
            reason: '$locale announces a bare number with no direction',
          );
        }
        expect(
          incoming,
          isNot(outgoing),
          reason: '$locale cannot tell the two directions apart',
        );
      }
    });
  });
}
