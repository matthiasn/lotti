import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_composer_header.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) => Column(
              children: [
                CheckInComposerHeader(
                  relationshipId: testRelationship.meta.id,
                  handle: handle,
                  title: 'Log check-in',
                ),
              ],
            ),
          ),
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
    expect(statusColor(tester), tokens.colors.alert.error.ink);

    publish(CheckInComposerStatus.paused);
    await tester.pump();
    expect(status(tester), 'Paused');

    publish(CheckInComposerStatus.transcribing);
    await tester.pump();
    expect(status(tester), 'Transcribing…');
    expect(statusColor(tester), tokens.colors.interactive.enabled);

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

  testWidgets('the close control pops the route', (tester) async {
    await pump(tester);
    expect(find.text('Log check-in'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('check-in-close')));
    await tester.pumpAndSettle();
    expect(find.text('Log check-in'), findsNothing);
  });

  testWidgets('the height is the taller of the avatar and the two text '
      "lines between its paddings, at the reader's text scale", (
    tester,
  ) async {
    await pump(tester);
    const tokens = dsTokensDark;
    final lines =
        tokens.typography.lineHeight.heading3 +
        tokens.typography.lineHeight.bodySmall;
    final atRest = 12 + (lines > 40 ? lines : 40) + 12;
    expect(tester.getSize(find.byType(CheckInComposerHeader)).height, atRest);
    expect(CheckInComposerHeader.height(tokens, TextScaler.noScaling), atRest);

    // Doubled text no longer fits beside the avatar: the header grows with
    // the lines rather than clipping the status line.
    expect(
      CheckInComposerHeader.height(tokens, const TextScaler.linear(2)),
      12 + lines * 2 + 12,
    );
  });
}
