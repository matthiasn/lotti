import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_composer_header.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../test_utils/screenshot_harness.dart' show loadAppFonts;
import '../../../../widget_test_utils.dart';

void main() {
  // The status line picks its wording by measuring it; the wide test font
  // would shed every tier, so pin the bundled fonts.
  setUpAll(() async {
    registerAllFallbackValues();
    await loadAppFonts();
  });

  late MockRelationshipRepository repository;
  late CheckInFormHandle handle;
  final at = DateTime(2026, 8, 1, 14, 55);

  CheckInEntry checkIn(DateTime when) => CheckInEntry(
    meta: Metadata(
      id: 'c-${when.millisecondsSinceEpoch}',
      createdAt: when,
      updatedAt: when,
      dateFrom: when,
      dateTo: when,
    ),
    data: CheckInData(
      relationshipId: testRelationship.meta.id,
      interactionType: CheckInInteractionType.call,
    ),
  );

  setUp(() async {
    await setUpTestGetIt();
    repository = MockRelationshipRepository();
    handle = CheckInFormHandle();
    when(
      () => repository.getRelationshipById(any()),
    ).thenAnswer((_) async => testRelationship);
    when(
      () => repository.getEntriesForCheckIns(any()),
    ).thenAnswer((_) async => const {});
    when(
      () => repository.getCheckInsForRelationship(any()),
    ).thenAnswer((_) async => [checkIn(at)]);
    when(
      () => repository.getLinkedTasks(any()),
    ).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    handle.dispose();
    await tearDownTestGetIt();
  });

  Future<void> pump(
    WidgetTester tester, {
    TextScaler textScaler = TextScaler.noScaling,
    double width = 390,
    bool editing = false,
    bool unresolved = false,
  }) async {
    if (unresolved) {
      // Before the person's row has been read: the header still has to hold
      // the avatar's place.
      when(
        () => repository.getRelationshipById(any()),
      ).thenAnswer((_) async => null);
    }
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Column(
              children: [
                SizedBox(
                  width: width,
                  child: CheckInComposerHeader(
                    editing: editing,
                    relationshipId: testRelationship.meta.id,
                    handle: handle,
                    title: 'Log check-in',
                  ),
                ),
              ],
            ),
          ),
        ),
        mediaQueryData: MediaQueryData(
          size: Size(width, 844),
          textScaler: textScaler,
        ),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  void publish(CheckInComposerStatus status) => handle.publish(
    save: null,
    delete: null,
    dismiss: null,
    unfocus: null,
    block: CheckInSaveBlock.emptyNarrative,
    status: status,
    summary: '',
  );

  String status(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('check-in-composer-status')))
      .data!;

  Color statusColor(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('check-in-composer-status')))
      .style!
      .color!;

  testWidgets('at rest: the avatar, the title, and who plus when they last '
      'spoke', (tester) async {
    await pump(tester);
    expect(find.byType(PersonaAvatar), findsOneWidget);
    expect(find.text('Log check-in'), findsOneWidget);
    expect(status(tester), 'with Anna · last spoke Sat 1 Aug');
  });

  testWidgets('a person with no check-in yet says so', (tester) async {
    when(
      () => repository.getCheckInsForRelationship(any()),
    ).thenAnswer((_) async => const []);
    await pump(tester);
    expect(status(tester), 'with Anna · no check-in yet');
  });

  testWidgets('the status line follows the handle, in its phase colour', (
    tester,
  ) async {
    await pump(tester);
    final tokens = tester
        .element(find.byKey(const ValueKey('check-in-composer-status')))
        .designTokens;

    publish(CheckInComposerStatus.recording);
    await tester.pump();
    expect(status(tester), 'Recording');
    // The red dot says live; the word stays in the quiet ink, so error red
    // on this surface means only a failure.
    expect(statusColor(tester), tokens.colors.text.mediumEmphasis);

    publish(CheckInComposerStatus.paused);
    await tester.pump();
    expect(status(tester), 'Paused');
    // A glyph as well as the word: the state reads without its colour.
    expect(find.byIcon(LottiIcons.pause), findsOneWidget);
    expect(statusColor(tester), tokens.colors.text.mediumEmphasis);

    publish(CheckInComposerStatus.transcribing);
    await tester.pump();
    expect(status(tester), 'Transcribing…');
    // The spinner says busy; the words stay quiet, so accent on text means
    // pressable everywhere.
    expect(statusColor(tester), tokens.colors.text.mediumEmphasis);

    // A failure wears its tone on the word as well as the glyph — the
    // briefing card's rule for its status line, so the two surfaces read
    // one way.
    publish(CheckInComposerStatus.transcriptMissing);
    await tester.pump();
    expect(status(tester), 'Transcript not received');
    expect(statusColor(tester), tokens.colors.alert.warning.ink);

    publish(CheckInComposerStatus.transcriptionUnavailable);
    await tester.pump();
    expect(status(tester), 'No transcription model');
    expect(statusColor(tester), tokens.colors.alert.warning.ink);

    publish(CheckInComposerStatus.microphoneDenied);
    await tester.pump();
    expect(status(tester), 'Microphone unavailable');
    expect(statusColor(tester), tokens.colors.alert.error.ink);

    publish(CheckInComposerStatus.recordingFailed);
    await tester.pump();
    expect(status(tester), "Recording didn't start");
    expect(statusColor(tester), tokens.colors.alert.error.ink);

    publish(CheckInComposerStatus.recordingNotSaved);
    await tester.pump();
    expect(status(tester), 'Recording not saved');
    expect(statusColor(tester), tokens.colors.alert.error.ink);

    publish(CheckInComposerStatus.recorderBusy);
    await tester.pump();
    expect(status(tester), 'Recorder busy');
    expect(statusColor(tester), tokens.colors.alert.warning.ink);

    publish(CheckInComposerStatus.idle);
    await tester.pump();
    expect(status(tester), 'with Anna · last spoke Sat 1 Aug');
  });

  testWidgets('at large text the avatar gives its width to the title', (
    tester,
  ) async {
    await pump(tester, textScaler: const TextScaler.linear(1.6));
    expect(find.byType(PersonaAvatar), findsNothing);
    expect(find.text('Log check-in'), findsOneWidget);
    // The line sheds the date before it sheds the person — and assistive
    // technology still hears the whole of it.
    expect(status(tester), 'with Anna');
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('check-in-composer-status')))
          .semanticsLabel,
      'with Anna · last spoke Sat 1 Aug',
    );
  });

  testWidgets('editing an existing check-in, the ladder starts at the name: '
      'the chip row is the one source of its date', (tester) async {
    await pump(tester, editing: true);
    expect(status(tester), 'with Anna');
  });

  testWidgets('the status line is live for news, not for the resting '
      'subtitle', (tester) async {
    await pump(tester);
    SemanticsNode node() => tester.getSemantics(
      find.byKey(const ValueKey('check-in-composer-status')),
    );
    expect(node().flagsCollection.isLiveRegion, isFalse);
    publish(CheckInComposerStatus.recording);
    await tester.pump();
    expect(node().flagsCollection.isLiveRegion, isTrue);
    publish(CheckInComposerStatus.transcribing);
    await tester.pump();
    expect(node().flagsCollection.isLiveRegion, isTrue);
    // A failure is the card's to announce — its title is the next step —
    // so the header goes quiet and one region speaks per event.
    publish(CheckInComposerStatus.microphoneDenied);
    await tester.pump();
    expect(node().flagsCollection.isLiveRegion, isFalse);
    publish(CheckInComposerStatus.transcriptMissing);
    await tester.pump();
    expect(node().flagsCollection.isLiveRegion, isFalse);
  });

  testWidgets('on a narrow header the status keeps the name, not the date — '
      'and the bare name is the last rung', (tester) async {
    await pump(tester, width: 240);
    expect(status(tester), 'with Anna');
    await pump(tester, width: 150);
    expect(status(tester), 'Anna');
  });

  testWidgets('the close control asks the form to dismiss, so a draft is '
      'guarded the same way as Cancel', (tester) async {
    await pump(tester);
    var dismissed = 0;
    handle.publish(
      save: null,
      delete: null,
      dismiss: () async => dismissed++,
      unfocus: null,
      block: CheckInSaveBlock.emptyNarrative,
      status: CheckInComposerStatus.idle,
      summary: '',
    );
    await tester.tap(find.byKey(const ValueKey('check-in-close')));
    await tester.pump();
    expect(dismissed, 1);
    expect(find.text('Log check-in'), findsOneWidget);
  });

  testWidgets('the height is the taller of the avatar and the two text '
      "lines between its paddings, at the reader's text scale", (
    tester,
  ) async {
    await pump(tester);
    const tokens = dsTokensDark;
    double line(TextStyle style, double scale) =>
        (style.fontSize! * (style.height ?? 1) * scale).ceilToDouble();
    final title = tokens.typography.styles.heading.heading3;
    final status = tokens.typography.styles.body.bodySmall;
    final lines = line(title, 1) + line(status, 1);
    // step6 above (clear of the sheet's drag handle), step4 below. The floor
    // is the avatar's own diameter, so it follows the token rather than a
    // literal that would quietly stop matching it.
    final atRest =
        24 +
        (lines > ControlSizes.avatarCompact
            ? lines
            : ControlSizes.avatarCompact) +
        12;
    expect(tester.getSize(find.byType(CheckInComposerHeader)).height, atRest);
    expect(CheckInComposerHeader.height(tokens, TextScaler.noScaling), atRest);

    // Doubled text no longer fits beside the avatar: the header grows with
    // the lines — two for a title the sheet measured as wrapping — rather
    // than clipping the status line.
    expect(
      CheckInComposerHeader.height(
        tokens,
        const TextScaler.linear(2),
        titleLines: 2,
      ),
      24 + line(title, 2) * 2 + line(status, 2) + 12,
    );
  });

  // Codex review on #4395: the avatar moved onto its own token while the
  // slot it sits in still reserved `spacing.step8`. The two are the same 40
  // today, so nothing looked wrong — until the avatar is retuned, when the
  // face either overflows the toolbar or leaves a hole, and the header jumps
  // as the person resolves. Both sides are pinned to the one token here.
  testWidgets('the avatar fills the slot the token names', (tester) async {
    await pump(tester);

    expect(
      tester.widget<PersonaAvatar>(find.byType(PersonaAvatar)).size,
      ControlSizes.avatarCompact,
    );
    expect(
      CheckInComposerHeader.height(dsTokensDark, TextScaler.noScaling),
      greaterThanOrEqualTo(ControlSizes.avatarCompact),
      reason: 'the row is at least as tall as the face it carries',
    );
  });

  testWidgets('before the person resolves, the slot is still held', (
    tester,
  ) async {
    await pump(tester, unresolved: true);

    expect(find.byType(PersonaAvatar), findsNothing);
    final placeholder = tester.widget<SizedBox>(
      find
          .descendant(
            of: find.byType(CheckInComposerHeader),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(
      placeholder.width,
      ControlSizes.avatarCompact,
      reason: 'the header must not jump when the person arrives',
    );
    expect(placeholder.height, ControlSizes.avatarCompact);
  });

  testWidgets('the title is measured against the width it will get: one '
      'line at ordinary scale, and at large text only as many as it wraps '
      'to, capped at two', (tester) async {
    await pump(tester);
    final context = tester.element(find.byType(CheckInComposerHeader));
    const tokens = dsTokensDark;
    final style = ModalUtils.modalTitleStyle(context);
    int lines(String title, double scale, double width) =>
        CheckInComposerHeader.titleLinesFor(
          title: title,
          style: style,
          scaler: TextScaler.linear(scale),
          tokens: tokens,
          width: width,
          direction: TextDirection.ltr,
        );
    expect(lines('A very long title that would wrap', 1, 200), 1);
    expect(lines('Log check-in', 1.6, 402), 1);
    expect(lines('A very long title that would wrap', 1.6, 402), 2);
    expect(lines('A title that wraps onto three or four lines', 2, 200), 2);
  });
}
