import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  // A Thursday, mid-morning.
  final now = DateTime(2026, 8, 13, 10, 30);
  final trackingStart = DateTime(2026, 7, 1, 9);

  RelationshipListItem item({
    String id = 'rel-1',
    String title = 'Anna',
    bool important = true,
    int? cadenceDays = 7,
    DateTime? lastCheckInAt,
    CheckInInteractionType lastType = CheckInInteractionType.call,
    RelationshipStatus? status,
    String? avatarImageId,
    AvatarCrop? avatarCrop,
  }) => (
    relationship: RelationshipEntry(
      meta: Metadata(
        id: id,
        createdAt: trackingStart,
        updatedAt: trackingStart,
        dateFrom: trackingStart,
        dateTo: trackingStart,
      ),
      data: RelationshipData(
        title: title,
        important: important,
        checkInCadenceDays: cadenceDays,
        avatarImageId: avatarImageId,
        avatarCrop: avatarCrop,
        status:
            status ??
            RelationshipStatus.active(
              id: 'status-$id',
              createdAt: trackingStart,
              utcOffset: 0,
            ),
      ),
    ),
    lastCheckIn: lastCheckInAt == null
        ? null
        : CheckInEntry(
            meta: Metadata(
              id: 'check-$id',
              createdAt: lastCheckInAt,
              updatedAt: lastCheckInAt,
              dateFrom: lastCheckInAt,
              dateTo: lastCheckInAt,
            ),
            data: CheckInData(relationshipId: id, interactionType: lastType),
          ),
  );

  Future<void> pump(
    WidgetTester tester,
    RelationshipListItem item, {
    bool selected = false,
    VoidCallback? onTap,
  }) => withClock(Clock.fixed(now), () async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        PeopleListRow(item: item, selected: selected, onTap: onTap ?? () {}),
      ),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('the status line is the last contact — what, when, cadence — '
      'with the mono voice on the date alone', (tester) async {
    await pump(tester, item(lastCheckInAt: DateTime(2026, 8, 13, 9, 5)));

    expect(
      find.text('Call · Today 09:05 · Weekly', findRichText: true),
      findsOneWidget,
    );

    // Mono tabulates a date down the column; on `Call` and `Weekly` it only
    // costs measure, which is what wrapped the line in the desktop rail.
    final fonts = _spanFonts(tester);
    expect(fonts['Today 09:05'], 'Inconsolata');
    expect(
      fonts['Call · '],
      isNot('Inconsolata'),
      reason: 'the prose around the date is proportional',
    );
    expect(fonts[' · Weekly'], isNot('Inconsolata'));
  });

  testWidgets('a status line with no date in it stays one plain string', (
    tester,
  ) async {
    // Not enrolled and never contacted: `Just added · Weekly`, no date to
    // set in mono, so the line must not become a one-span RichText.
    await pump(tester, item(important: false));

    final line = tester.widget<RelationshipLineWithDate>(
      find.byKey(const ValueKey('people-row-status')),
    );
    expect(line.text, 'Just added · Weekly');
    expect(line.date, isNull);
    expect(line.style.fontFamily, isNot('Inconsolata'));
  });

  testWidgets('a person never contacted reads Just added, the cadence, and '
      'when the first check-in falls due', (tester) async {
    await pump(tester, item(cadenceDays: 30));

    // Tracking started 1 Jul; a monthly cadence falls due on 31 Jul.
    expect(
      find.text(
        'Just added · Monthly · first due Fri 31 Jul',
        findRichText: true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('the sparkle marks an important person and nobody else', (
    tester,
  ) async {
    await pump(tester, item());
    expect(find.byKey(const ValueKey('people-row-important')), findsOneWidget);

    await pump(tester, item(important: false));
    expect(find.byKey(const ValueKey('people-row-important')), findsNothing);
  });

  // It is the one thing distinguishing an enrolled person on this row, and
  // it used to be an 8px speck — below IconSizes.xs, the smallest tier the
  // system defines — in a colour, with nothing said about it.
  testWidgets('the sparkle is legible, and says what it means', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, item());

    final icon = tester.widget<Icon>(
      find.byKey(const ValueKey('people-row-important')),
    );
    expect(icon.size, IconSizes.xs);

    final messages = tester.element(find.byType(PeopleListRow)).messages;
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('people-row-important')))
          .label,
      contains(messages.relationshipImportantLabel),
      reason:
          'colour alone reaches neither a screen reader nor a '
          'colour-blind reader',
    );
    semantics.dispose();
  });

  testWidgets('a dormant person keeps the important flag but loses the '
      'marker — the runtime clears their reminders', (tester) async {
    await pump(
      tester,
      item(
        // ignore: avoid_redundant_argument_values
        important: true,
        status: RelationshipStatus.dormant(
          id: 's',
          createdAt: now,
          utcOffset: 0,
        ),
      ),
    );

    // The sparkle is announced as "Reminders on"; a dormant person will
    // not get any, so claiming it here would be false in the one place a
    // screen reader hears it.
    expect(find.byKey(const ValueKey('people-row-important')), findsNothing);
    expect(find.text('Dormant'), findsOneWidget);
  });

  group('the pill tells the truth about the cadence', () {
    testWidgets('lapsed: days over, warning-tinted — never "Due Sun"', (
      tester,
    ) async {
      // Weekly, last contact 3 Aug 09:00 → due 10 Aug → 3 days over on the 13th.
      await pump(tester, item(lastCheckInAt: DateTime(2026, 8, 3, 9)));

      expect(find.text('3 days over'), findsOneWidget);
      expect(find.textContaining('Due '), findsNothing);
      final pill = tester.widget<DsPill>(
        find.byKey(const ValueKey('people-row-pill-overdue')),
      );
      final tokens = tester.element(find.byType(PeopleListRow)).designTokens;
      expect(pill.variant, DsPillVariant.tinted);
      expect(pill.color, tokens.colors.alert.warning.defaultColor);
    });

    testWidgets('due within the week: the weekday', (tester) async {
      // Weekly, last contact this morning → due Thu 20 Aug.
      await pump(tester, item(lastCheckInAt: DateTime(2026, 8, 13, 9)));
      expect(find.text('Due Thu'), findsOneWidget);
    });

    testWidgets('further out: nothing — the On track band already said it', (
      tester,
    ) async {
      await pump(
        tester,
        item(cadenceDays: 30, lastCheckInAt: DateTime(2026, 8, 1, 9)),
      );
      // The row sits under an `On track` heading; a pill repeating the word
      // spends the width the name needs to say nothing new.
      expect(find.text('On track'), findsNothing);
      expect(find.byType(PeopleCadencePillWidget), findsNothing);
    });

    testWidgets('due today says so, in the warning tint', (tester) async {
      // Weekly, last contact a week ago this morning → due today.
      await pump(tester, item(lastCheckInAt: DateTime(2026, 8, 6, 9)));
      expect(find.text('Due today'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('people-row-pill-overdue')),
        findsOneWidget,
      );
    });

    testWidgets(
      'an enrolled person without a stored cadence follows the '
      "runtime's monthly default — the line names it, the pill counts by it",
      (tester) async {
        // Tracking since 1 Jul, contacted 3 Aug: monthly default → due 2 Sep.
        await pump(
          tester,
          item(cadenceDays: null, lastCheckInAt: DateTime(2026, 8, 3, 9)),
        );
        expect(
          find.text('Call · Mon 3 Aug 09:00 · Monthly', findRichText: true),
          findsOneWidget,
        );
        expect(find.byType(PeopleCadencePillWidget), findsNothing);
      },
    );

    testWidgets('not important: not enrolled, whatever the cadence says', (
      tester,
    ) async {
      await pump(
        tester,
        item(important: false, lastCheckInAt: DateTime(2026, 8, 3, 9)),
      );
      // Under the `Not enrolled` heading the pill would be the same two
      // words again, so the row drops it.
      expect(find.text('No reminders'), findsNothing);
      expect(find.byType(PeopleCadencePillWidget), findsNothing);
      expect(find.textContaining('days over'), findsNothing);
      // The stored setting is still what the line names.
      expect(
        find.text('Call · Mon 3 Aug 09:00 · Weekly', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a person who is not enrolled is never given a first-due '
        'day — the runtime schedules none for them', (tester) async {
      await pump(tester, item(important: false, cadenceDays: 30));
      expect(find.text('Just added · Monthly'), findsOneWidget);
      expect(find.textContaining('first due'), findsNothing);
    });

    testWidgets('dormant and archived name their status', (tester) async {
      await pump(
        tester,
        item(
          status: RelationshipStatus.dormant(
            id: 'd',
            createdAt: trackingStart,
            utcOffset: 0,
          ),
        ),
      );
      expect(find.text('Dormant'), findsOneWidget);

      await pump(
        tester,
        item(
          status: RelationshipStatus.archived(
            id: 'a',
            createdAt: trackingStart,
            utcOffset: 0,
          ),
        ),
      );
      expect(find.text('Archived'), findsOneWidget);
    });
  });

  testWidgets('the selected row wears the selected wash; an unselected one '
      'sits on the page surface', (tester) async {
    await pump(tester, item(), selected: true);
    final tokens = tester.element(find.byType(PeopleListRow)).designTokens;
    Material material() => tester.widget<Material>(
      find.descendant(
        of: find.byType(PeopleListRow),
        matching: find.byType(Material),
      ),
    );
    expect(material().color, tokens.colors.surface.selected);

    await pump(tester, item());
    expect(material().color, tokens.colors.background.level01);
  });

  testWidgets('tapping anywhere on the row fires onTap', (tester) async {
    var taps = 0;
    await pump(tester, item(), onTap: () => taps++);
    await tester.tap(find.textContaining('Anna', findRichText: true));
    expect(taps, 1);
  });

  test(
    'peopleCadencePillOf and the row agree on the kinds the row renders',
    () {
      // Every kind the model can produce has a rendering branch; this pins the
      // enum so a new kind cannot be added without the row learning its label.
      expect(PeopleCadencePillKind.values, hasLength(6));
    },
  );

  testWidgets("hands the person's photo and its framing to the avatar, and "
      'the avatar stays the same size with or without one', (tester) async {
    const crop = AvatarCrop(x: 0.2, y: 0.3, scale: 2);
    await pump(tester, item(avatarImageId: 'image-1', avatarCrop: crop));

    final avatar = tester.widget<PersonaAvatar>(find.byType(PersonaAvatar));
    expect(avatar.imageId, 'image-1');
    expect(avatar.crop, crop);
    expect(avatar.id, 'rel-1', reason: 'the accent still comes from the id');
    expect(
      avatar.size,
      40,
      reason: 'the row does not grow because the person has a face',
    );
  });
}

/// The fonts of the status line's spans, as {text: fontFamily}.
///
/// The line is a `Text.rich` so the date can wear the mono face while the
/// prose around it does not; this reads that tree back rather than trusting
/// one style on the whole widget.
Map<String, String?> _spanFonts(WidgetTester tester) {
  final fonts = <String, String?>{};
  tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const ValueKey('people-row-status')),
          matching: find.byType(Text),
        ),
      )
      .textSpan!
      .visitChildren((span) {
        if (span is TextSpan && span.text != null) {
          fonts[span.text!] = span.style?.fontFamily;
        }
        return true;
      });
  return fonts;
}
