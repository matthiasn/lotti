import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/events/ui/widgets/event_timeline.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../test_utils/broken_image_provider.dart';
import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpTimeline(
    WidgetTester tester,
    List<EventTimelineEntry> entries, {
    ValueChanged<String>? onOpenEntry,
    double width = 400,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: EventTimeline(entries: entries, onOpenEntry: onOpenEntry),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<DesignSystemTimelineRow> rows(WidgetTester tester) => tester
      .widgetList<DesignSystemTimelineRow>(find.byType(DesignSystemTimelineRow))
      .toList();

  IconData glyphOf(DesignSystemTimelineRow row) =>
      (row.leading as DesignSystemTimelineTile).icon;

  const note = EventTimelineEntry(
    timeLabel: '18:50',
    kind: EventTimelineKind.note,
    entryId: 'note-1',
    text: 'Pressure seals green.',
  );
  const photo = EventTimelineEntry(
    timeLabel: '19:05',
    kind: EventTimelineKind.photo,
    entryId: 'photo-1',
    text: 'The orbital habitat at dusk.',
    photos: [EventPhoto(BrokenImageProvider())],
  );
  const recording = EventTimelineEntry(
    timeLabel: '19:20',
    kind: EventTimelineKind.audio,
    entryId: 'audio-1',
    durationLabel: '0:42',
    text: 'Toast from the captain.',
  );
  const timeSpan = EventTimelineEntry(
    timeLabel: '19:30',
    kind: EventTimelineKind.timeRecording,
    entryId: 'time-1',
    endTimeLabel: '20:00',
    durationLabel: '30m',
    text: 'Loading the cargo pods.',
  );

  group('rows', () {
    testWidgets('each entry is a design-system timeline row naming its time '
        'and kind, with the kind as the glyph', (tester) async {
      await pumpTimeline(tester, [note, photo, recording, timeSpan]);

      final all = rows(tester);
      expect(all.map(glyphOf), [
        LottiIcons.note,
        LottiIcons.image,
        LottiIcons.mic,
        LottiIcons.timer,
      ]);
      expect(all.map((row) => row.semanticsLabel), [
        'Note, 18:50',
        'Photo, 19:05',
        'Voice note, 19:20',
        'Time recording, 19:30',
      ]);
      expect(find.text('18:50 · Note'), findsOneWidget);
      expect(find.text('19:05 · Photo'), findsOneWidget);
      // The rail ends at the last row, and only there.
      expect(all.map((row) => row.last), [false, false, false, true]);
    });

    testWidgets('a note reads as folded words', (tester) async {
      await pumpTimeline(tester, [note]);

      final words = tester.widget<FoldedWords>(find.byType(FoldedWords));
      expect(words.words, 'Pressure seals green.');
      expect(words.id, 'note-1');
    });

    testWidgets('an empty note is a row with no body', (tester) async {
      await pumpTimeline(tester, [
        const EventTimelineEntry(
          timeLabel: '18:50',
          kind: EventTimelineKind.note,
          entryId: 'note-1',
          text: '   ',
        ),
      ]);

      expect(rows(tester).single.body, isNull);
      expect(find.byType(FoldedWords), findsNothing);
    });

    testWidgets('a time recording shows its span and its words', (
      tester,
    ) async {
      await pumpTimeline(tester, [timeSpan]);

      final bar = tester.widget<TimeSpanBar>(find.byType(TimeSpanBar));
      expect(bar.startLabel, '19:30');
      expect(bar.endLabel, '20:00');
      expect(bar.durationLabel, '30m');
      expect(find.text('Loading the cargo pods.'), findsOneWidget);
    });

    testWidgets('a time recording without its span labels reads as a note', (
      tester,
    ) async {
      await pumpTimeline(tester, [
        const EventTimelineEntry(
          timeLabel: '19:30',
          kind: EventTimelineKind.timeRecording,
          entryId: 'time-1',
          text: 'Loading the cargo pods.',
        ),
      ]);

      expect(find.byType(TimeSpanBar), findsNothing);
      expect(glyphOf(rows(tester).single), LottiIcons.note);
      expect(find.text('19:30 · Note'), findsOneWidget);
      expect(find.text('Loading the cargo pods.'), findsOneWidget);
    });

    testWidgets('a recording plays through the supplied player, with its '
        'transcript under it', (tester) async {
      await pumpTimeline(tester, [
        const EventTimelineEntry(
          timeLabel: '19:20',
          kind: EventTimelineKind.audio,
          entryId: 'audio-1',
          text: 'Toast from the captain.',
          player: Text('PLAYER'),
        ),
      ]);

      expect(find.text('PLAYER'), findsOneWidget);
      final transcript = tester.widget<RecordingTranscript>(
        find.byType(RecordingTranscript),
      );
      expect(transcript.transcript, 'Toast from the captain.');
      expect(transcript.id, 'audio-1');
    });

    testWidgets('without a player a recording still says it exists', (
      tester,
    ) async {
      await pumpTimeline(tester, [recording]);

      expect(find.byIcon(LottiIcons.playCircled), findsOneWidget);
      expect(find.text('0:42'), findsOneWidget);
    });

    testWidgets('a recording without words has no transcript', (tester) async {
      await pumpTimeline(tester, [
        const EventTimelineEntry(
          timeLabel: '19:20',
          kind: EventTimelineKind.audio,
          entryId: 'audio-1',
        ),
      ]);

      expect(find.byType(RecordingTranscript), findsNothing);
      // The placeholder falls back to the kind when there is no duration.
      expect(find.text('Voice note'), findsOneWidget);
    });
  });

  group('photos', () {
    /// The rendered size of the first photo band.
    Size band(WidgetTester tester) => tester.getSize(
      find
          .descendant(
            of: find.byType(EventTimelinePhotoBand),
            matching: find.byType(ClipRRect),
          )
          .first,
    );

    testWidgets('the photo sits in the footer, its caption under it', (
      tester,
    ) async {
      await pumpTimeline(tester, [photo]);

      final row = rows(tester).single;
      expect(row.body, isNull);
      expect(row.footer, isNotNull);
      final picture = tester.getRect(find.byType(EventTimelinePhotoBand));
      final caption = tester.getRect(
        find.text('The orbital habitat at dusk.'),
      );
      expect(caption.top, greaterThanOrEqualTo(picture.bottom));
      final text = tester.widget<Text>(
        find.text('The orbital habitat at dusk.'),
      );
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('a wide, short band on a phone column', (tester) async {
      await pumpTimeline(tester, [photo], width: 360);

      final size = band(tester);
      expect(size.width / size.height, greaterThan(2.3));
      expect(size.height, lessThan(140));
    });

    testWidgets('a wide column caps the height', (tester) async {
      await pumpTimeline(tester, [photo], width: 1000);

      expect(band(tester).height, EventTimelinePhotoBand.maxHeight);
    });

    testWidgets('a narrow column keeps a readable minimum', (tester) async {
      await pumpTimeline(tester, [photo], width: 200);

      expect(band(tester).height, EventTimelinePhotoBand.minHeight);
    });

    test('between the bounds the height follows the width', () {
      expect(EventTimelinePhotoBand.heightFor(240), 100);
      expect(EventTimelinePhotoBand.heightFor(360), 150);
      expect(EventTimelinePhotoBand.heightFor(100), 96);
      expect(EventTimelinePhotoBand.heightFor(2000), 180);
    });

    testWidgets('a picture that fails to load leaves a neutral fill', (
      tester,
    ) async {
      await pumpTimeline(tester, [photo]);
      await tester.pump();

      expect(tester.takeException(), isNull);
      final fill = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(Image),
          matching: find.byType(ColoredBox),
        ),
      );
      final context = tester.element(find.byType(EventTimeline));
      expect(fill.color, context.designTokens.colors.background.level03);
    });

    testWidgets('each photo of a row gets its own band', (tester) async {
      await pumpTimeline(tester, [
        const EventTimelineEntry(
          timeLabel: '19:05',
          kind: EventTimelineKind.photo,
          entryId: 'photo-1',
          photos: [
            EventPhoto(BrokenImageProvider()),
            EventPhoto(BrokenImageProvider()),
          ],
        ),
      ]);

      expect(find.byType(EventTimelinePhotoBand), findsNWidgets(2));
    });
  });

  group('opening', () {
    testWidgets('a row with an entry opens it', (tester) async {
      final opened = <String>[];
      await pumpTimeline(tester, [note, photo], onOpenEntry: opened.add);

      await tester.tap(find.text('Pressure seals green.'));
      await tester.tap(find.text('19:05 · Photo'));

      expect(opened, ['note-1', 'photo-1']);
    });

    testWidgets('a row without an entry id is inert', (tester) async {
      await pumpTimeline(tester, [
        const EventTimelineEntry(
          timeLabel: '18:50',
          kind: EventTimelineKind.note,
          text: 'Loose words.',
        ),
      ], onOpenEntry: (_) => fail('nothing to open'));

      expect(rows(tester).single.onTap, isNull);
    });

    testWidgets('without a handler every row is inert', (tester) async {
      await pumpTimeline(tester, [note, photo]);

      expect(rows(tester).every((row) => row.onTap == null), isTrue);
    });
  });
}
