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
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Column(
              children: [
                SizedBox(
                  width: width,
                  child: CheckInComposerHeader(
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

    publish(CheckInComposerStatus.transcriptMissing);
    await tester.pump();
    expect(status(tester), 'Transcript not received');
    expect(statusColor(tester), tokens.colors.alert.warning.ink);

    publish(CheckInComposerStatus.transcriptionUnavailable);
    await tester.pump();
    expect(status(tester), 'No transcription model');

    publish(CheckInComposerStatus.microphoneDenied);
    await tester.pump();
    expect(status(tester), 'Microphone unavailable');
    expect(statusColor(tester), tokens.colors.alert.error.ink);

    publish(CheckInComposerStatus.recordingFailed);
    await tester.pump();
    expect(status(tester), "Recording didn't start");

    publish(CheckInComposerStatus.recordingNotSaved);
    await tester.pump();
    expect(status(tester), 'Recording not saved');

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
    // step6 above (clear of the sheet's drag handle), step4 below.
    final atRest = 24 + (lines > 40 ? lines : 40) + 12;
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
