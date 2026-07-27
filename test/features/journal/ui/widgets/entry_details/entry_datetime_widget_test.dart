import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// `show DateFormat` — intl also exports a TextDirection that would shadow the
// dart:ui one used for the layout measurements below.
import 'package:intl/intl.dart' show DateFormat;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

/// 21:54 — the time from the bug report, chosen because it renders
/// unambiguously differently under each clock ("21:54" vs "9:54 PM") and so a
/// test cannot pass by accident on a 12-hour default.
final _dateFrom = DateTime(2026, 7, 13, 21, 54);

final _entry = JournalEntry(
  meta: Metadata(
    id: 'datetime-widget-entry',
    createdAt: _dateFrom,
    dateFrom: _dateFrom,
    dateTo: _dateFrom.add(const Duration(minutes: 4)),
    updatedAt: _dateFrom,
  ),
  entryText: const EntryText(plainText: 'note'),
);

/// An id the database resolves to nothing, for the "entry not loaded yet" path.
const _missingEntryId = 'datetime-widget-missing';

/// The date half, formatted the way the widget formats it. Only the *time* half
/// is under test for locale correctness, so deriving the date this way keeps
/// the finders honest without weakening any assertion that matters.
String _dateTextFor(String locale) =>
    DateFormat.yMMMd(locale).format(_dateFrom);

void main() {
  group('EntryDatetimeWidget', () {
    final mockJournalDb = MockJournalDb();
    final mockEditorStateService = MockEditorStateService();

    setUpAll(() async {
      await getIt.reset();
      final mockUpdateNotifications = MockUpdateNotifications();
      when(() => mockUpdateNotifications.updateStream).thenAnswer(
        (_) => Stream<Set<String>>.fromIterable([]),
      );

      getIt
        ..registerSingleton<UpdateNotifications>(mockUpdateNotifications)
        ..registerSingleton<JournalDb>(mockJournalDb)
        ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
        ..registerSingleton<EditorStateService>(mockEditorStateService);

      when(
        () => mockJournalDb.journalEntityById(_entry.meta.id),
      ).thenAnswer((_) async => _entry);
      when(
        () => mockJournalDb.journalEntityById(_missingEntryId),
      ).thenAnswer((_) async => null);
      when(
        () => mockEditorStateService.getUnsavedStream(any(), any()),
      ).thenAnswer((_) => Stream<bool>.fromIterable([false]));
    });

    tearDownAll(() async => getIt.reset());

    /// Pumps the widget under an explicit width, clock and text scale.
    ///
    /// [width] maps straight to the horizontal space the header hands the
    /// timestamp; a null [width] leaves the width unbounded, the case the
    /// collapsed linked-entry preview creates with its own `Spacer`.
    Future<void> pump(
      WidgetTester tester, {
      double? width,
      bool prominent = false,
      bool use24Hour = false,
      Locale? locale,
      TextScaler textScaler = TextScaler.noScaling,
      String? entryId,
    }) async {
      Widget child = EntryDatetimeWidget(
        entryId: entryId ?? _entry.meta.id,
        prominent: prominent,
      );
      child = width == null
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: child,
            )
          : SizedBox(width: width, child: child);
      if (locale != null) {
        child = Localizations.override(
          context: tester.element(find.byType(Scaffold)),
          locale: locale,
          child: child,
        );
      }

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          child,
          mediaQueryData: phoneMediaQueryData.copyWith(
            alwaysUse24HourFormat: use24Hour,
            textScaler: textScaler,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Pumps once to obtain a context, then re-pumps with the locale override
    /// applied — `Localizations.override` needs a context to inherit the
    /// delegates from.
    Future<void> pumpWithLocale(
      WidgetTester tester,
      Locale locale, {
      required bool use24Hour,
      double width = 800,
    }) async {
      await pump(tester, width: width);
      await pump(
        tester,
        width: width,
        locale: locale,
        use24Hour: use24Hour,
      );
    }

    /// Scopes [matching] to the widget under test, so an assertion can never
    /// pass or fail on something the surrounding test harness happens to build.
    Finder inWidget(Finder matching) => find.descendant(
      of: find.byType(EntryDatetimeWidget),
      matching: matching,
    );

    /// The single [Text] the widget rendered, when it chose the one-line form.
    Text oneLineText(WidgetTester tester) =>
        tester.widget<Text>(inWidget(find.byType(Text)));

    DsTokens tokensOf(WidgetTester tester) =>
        tester.element(find.byType(EntryDatetimeWidget)).designTokens;

    /// The exact width the currently-rendered one-line form needs, so a test
    /// can sit deliberately either side of the wrap threshold instead of
    /// guessing at a breakpoint.
    ///
    /// Measures the string the widget actually produced rather than a literal,
    /// so the threshold stays exact even though the localized time carries a
    /// narrow no-break space before AM/PM.
    double renderedOneLineWidth(WidgetTester tester) {
      final text = oneLineText(tester);
      final painter = TextPainter(
        text: TextSpan(text: text.data, style: text.style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    group('clock format', () {
      testWidgets('a 24-hour device shows 24-hour time on an English locale', (
        tester,
      ) async {
        await pump(tester, width: 800, use24Hour: true);

        // The bug: an entry recorded at 21:54 read back as "9:54 PM" because
        // DateFormat.jm('en_US') is hard-wired to 12-hour and never consulted
        // the device clock.
        expect(find.textContaining('21:54'), findsOneWidget);
        expect(find.textContaining('PM'), findsNothing);
      });

      testWidgets('a 12-hour device still shows 12-hour time', (tester) async {
        await pump(tester, width: 800);

        expect(find.textContaining('9:54'), findsOneWidget);
        expect(find.textContaining('PM'), findsOneWidget);
        expect(find.textContaining('21:54'), findsNothing);
      });

      testWidgets(
        'the same entry renders differently under the two device clocks',
        (tester) async {
          await pump(tester, width: 800);
          final twelveHour = oneLineText(tester).data;

          await pump(tester, width: 800, use24Hour: true);
          final twentyFourHour = oneLineText(tester).data;

          // Guards the whole point of the fix: before it, the device setting
          // made no difference at all and these two were identical.
          expect(twelveHour, isNot(twentyFourHour));
        },
      );

      testWidgets(
        'a locale that is 24-hour by default ignores a 12-hour device flag',
        (tester) async {
          await pumpWithLocale(tester, const Locale('de'), use24Hour: false);

          // German has no AM/PM form to fall back to, so the locale wins.
          expect(find.textContaining('21:54'), findsOneWidget);
        },
      );

      testWidgets('the date half stays locale-formatted', (tester) async {
        await pumpWithLocale(tester, const Locale('de'), use24Hour: false);

        // "13. Juli 2026" in German, not "Jul 13, 2026" — the date formatting
        // must survive the change to how the time is formatted.
        expect(find.textContaining('Juli'), findsOneWidget);
        expect(find.textContaining('Jul 13, 2026'), findsNothing);
      });
    });

    group('type tier', () {
      testWidgets('prominent renders at subtitle2, high emphasis', (
        tester,
      ) async {
        await pump(tester, width: 800, prominent: true);

        final tokens = tokensOf(tester);
        final style = oneLineText(tester).style;
        expect(
          style?.fontSize,
          tokens.typography.styles.subtitle.subtitle2.fontSize,
        );
        expect(style?.color, tokens.colors.text.highEmphasis);
      });

      testWidgets('prominent is a step below the old subtitle1 title tier', (
        tester,
      ) async {
        await pump(tester, width: 800, prominent: true);

        final tokens = tokensOf(tester);
        // The reported defect: at subtitle1 (16/w600) the timestamp was the
        // loudest thing on the card. Asserting the *relation* rather than the
        // number keeps this meaningful if the ramp is ever retuned.
        expect(
          oneLineText(tester).style!.fontSize,
          lessThan(tokens.typography.styles.subtitle.subtitle1.fontSize!),
        );
      });

      testWidgets('the default renders at caption, low emphasis', (
        tester,
      ) async {
        await pump(tester, width: 800);

        final tokens = tokensOf(tester);
        final style = oneLineText(tester).style;
        expect(
          style?.fontSize,
          tokens.typography.styles.others.caption.fontSize,
        );
        // Quiet, recessive metadata tone (lowEmphasis ≈ 6:1, above the AA
        // floor) — it must not compete with the value or body.
        expect(style?.color, tokens.colors.text.lowEmphasis);
      });

      testWidgets('both tiers carry the shared numeric badge font features', (
        tester,
      ) async {
        await pump(tester, width: 800);
        expect(
          oneLineText(tester).style?.fontFeatures,
          numericBadgeFontFeatures,
        );

        await pump(tester, width: 800, prominent: true);
        expect(
          oneLineText(tester).style?.fontFeatures,
          numericBadgeFontFeatures,
        );
      });
    });

    group('one line versus stacked', () {
      testWidgets('one line when the width fits exactly', (tester) async {
        await pump(tester, width: 800, prominent: true);
        final needed = renderedOneLineWidth(tester);

        // Exactly the width it needs: the widget compares with <=, so this is
        // the last width that must still produce one line.
        await pump(tester, width: needed, prominent: true);

        expect(inWidget(find.byType(Column)), findsNothing);
        expect(oneLineText(tester).maxLines, 1);
      });

      testWidgets('stacks date over time one pixel below the threshold', (
        tester,
      ) async {
        await pump(tester, width: 800, prominent: true);
        final needed = renderedOneLineWidth(tester);

        await pump(tester, width: needed - 1, prominent: true);

        final dateFinder = find.text(_dateTextFor('en_US'));
        final timeFinder = find.textContaining('9:54');
        expect(dateFinder, findsOneWidget);
        expect(timeFinder, findsOneWidget);
        // The date sits above the time (natural reading order), left-aligned.
        final datePos = tester.getTopLeft(dateFinder);
        final timePos = tester.getTopLeft(timeFinder);
        expect(datePos.dy, lessThan(timePos.dy));
        expect(datePos.dx, equals(timePos.dx));
      });

      testWidgets(
        'the stack keeps the tier the one-line form would have used',
        (
          tester,
        ) async {
          await pump(tester, width: 40, prominent: true);

          final tokens = tokensOf(tester);
          final texts = tester.widgetList<Text>(
            find.descendant(
              of: find.byType(EntryDatetimeWidget),
              matching: find.byType(Text),
            ),
          );
          expect(texts.length, 2);
          // No intermediate ladder rung: both stacked lines are subtitle2, the
          // same size the wide layout uses.
          for (final text in texts) {
            expect(
              text.style?.fontSize,
              tokens.typography.styles.subtitle.subtitle2.fontSize,
            );
          }
        },
      );

      testWidgets('the two stacked lines read as one node to a screen reader', (
        tester,
      ) async {
        await pump(tester, width: 40, prominent: true);

        expect(
          inWidget(find.byType(MergeSemantics)),
          findsOneWidget,
        );
      });

      testWidgets('an unbounded width always keeps one line', (tester) async {
        await pump(tester, prominent: true);

        expect(inWidget(find.byType(MergeSemantics)), findsNothing);
        expect(oneLineText(tester).maxLines, 1);
      });

      testWidgets('a large text scale forces the stack at a width that fits '
          'unscaled', (tester) async {
        await pump(tester, width: 800, prominent: true);
        final needed = renderedOneLineWidth(tester);

        // Same width, doubled text: the fit measurement must take the scale
        // into account or the line silently ellipsizes instead of stacking.
        await pump(
          tester,
          width: needed,
          prominent: true,
          textScaler: const TextScaler.linear(2),
        );

        expect(inWidget(find.byType(MergeSemantics)), findsOneWidget);
      });
    });

    group('interaction', () {
      testWidgets('tapping the one-line timestamp opens the editor', (
        tester,
      ) async {
        await pump(tester, width: 800);

        await tester.tap(find.byType(EntryDatetimeWidget));
        await tester.pumpAndSettle();

        expect(find.text('Date & Time'), findsOneWidget);
        expect(find.text('Start time'), findsOneWidget);
        expect(find.text('End time'), findsOneWidget);
      });

      testWidgets('tapping the stacked timestamp opens the same editor', (
        tester,
      ) async {
        await pump(tester, width: 40);

        await tester.tap(find.text(_dateTextFor('en_US')));
        await tester.pumpAndSettle();

        expect(find.text('Date & Time'), findsOneWidget);
      });
    });

    group('missing entry', () {
      testWidgets('renders nothing when the entry cannot be resolved', (
        tester,
      ) async {
        await pump(tester, width: 800, entryId: _missingEntryId);

        expect(inWidget(find.byType(Text)), findsNothing);
        expect(inWidget(find.byType(GestureDetector)), findsNothing);
      });
    });
  });
}
