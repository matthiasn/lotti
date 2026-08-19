import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';
import 'package:lotti/widgets/timeline/timeline_view.dart';

import '../../widget_test_utils.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(makeTestableWidgetWithScaffold(child));

  TimelineBeat beat({
    String id = 'beat-1',
    String? entryId,
    String time = '09:14',
    String? kindLabel,
    IconData? glyph,
    Color? accent,
    TimelineBeatContent? content,
    Widget? trailing,
    VoidCallback? onTap,
  }) => TimelineBeat(
    id: id,
    entryId: entryId,
    timeLabel: time,
    kindLabel: kindLabel,
    glyph: glyph,
    accent: accent,
    trailing: trailing,
    onTap: onTap,
    content: content ?? const TimelineBeatContent.text('Morning walk done.'),
  );

  group('open affordance', () {
    testWidgets('a beat with no entry id is inert and shows no chevron', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(beats: [beat()]),
          ],
          onOpenBeat: (_) => fail('a beat with no entry id must not open'),
        ),
      );

      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('a beat with no handler is inert even when it has an id', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(beats: [beat(entryId: 'entry-1')]),
          ],
        ),
      );

      expect(find.byIcon(LottiIcons.chevronRight), findsNothing);
    });

    testWidgets('an openable beat reports the entry it was built from', (
      tester,
    ) async {
      String? opened;
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(beats: [beat(entryId: 'entry-42')]),
          ],
          onOpenBeat: (id) => opened = id,
        ),
      );

      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
      await tester.tap(find.text('Morning walk done.'));
      expect(opened, 'entry-42');
    });
  });

  group('beat-level tap and trailing slot', () {
    testWidgets('a beat-level onTap opens without an entry id and earns the '
        'chevron', (tester) async {
      var opened = 0;
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [beat(onTap: () => opened++)],
            ),
          ],
          onOpenBeat: (_) => fail('the beat tap outranks entry navigation'),
        ),
      );

      expect(find.byIcon(LottiIcons.chevronRight), findsOneWidget);
      await tester.tap(find.text('09:14'));
      expect(opened, 1);

      // Hover wiring: the row's ink rides a LOCAL transparent Material with
      // the design-system hover fill — painted on the Scaffold's Material it
      // would sit under the opaque card and never show.
      final ink = tester.widget<InkWell>(find.byType(InkWell).first);
      final tokens = tester.element(find.byType(TimelineView)).designTokens;
      expect(ink.hoverColor, tokens.colors.surface.hover);
      final material = tester.widget<Material>(
        find
            .ancestor(
              of: find.byType(InkWell).first,
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.type, MaterialType.transparency);
    });

    testWidgets('a trailing widget rides the header row, fully right-aligned', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                beat(
                  kindLabel: 'DAILY REFLECTION',
                  trailing: const Text('Met'),
                ),
              ],
            ),
          ],
        ),
      );

      final time = tester.getRect(find.text('09:14'));
      final kind = tester.getRect(find.text('DAILY REFLECTION'));
      final trailing = tester.getRect(find.text('Met'));
      final view = tester.getRect(find.byType(TimelineView));
      // One tight row: the status shares the line with the time and kind…
      expect(trailing.center.dy, closeTo(time.center.dy, 1));
      // …and sits at the trailing edge, past the leading labels.
      expect(trailing.left, greaterThan(kind.right));
      expect(trailing.right, greaterThan(view.center.dx));
    });
  });

  group('grouping', () {
    testWidgets(
      'renders a divider per labelled group, and none when unlabelled',
      (tester) async {
        await pump(
          tester,
          TimelineView(
            groups: [
              TimelineGroup(
                label: 'TODAY',
                beats: [beat(id: 'a')],
              ),
              TimelineGroup(
                label: 'YESTERDAY',
                beats: [beat(id: 'b')],
              ),
              TimelineGroup(beats: [beat(id: 'c')]),
            ],
          ),
        );

        expect(find.text('TODAY'), findsOneWidget);
        expect(find.text('YESTERDAY'), findsOneWidget);
        // Three beats, two dividers — the unlabelled group contributes none,
        // which is what keeps a single-day timeline (Events) divider-free.
        expect(find.byType(Divider), findsNWidgets(2));
      },
    );

    testWidgets('an empty group contributes neither divider nor tile', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            const TimelineGroup(label: 'EMPTY DAY', beats: []),
            TimelineGroup(label: 'TODAY', beats: [beat()]),
          ],
        ),
      );

      expect(find.text('EMPTY DAY'), findsNothing);
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('one entry linked twice renders twice rather than crashing', (
      tester,
    ) async {
      // Keying on the entry id alone made this a duplicate-key crash.
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                beat(id: 'same', entryId: 'same'),
                beat(id: 'same', entryId: 'same'),
              ],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Morning walk done.'), findsNWidgets(2));
    });
  });

  group('empty and paging', () {
    testWidgets("shows the caller's empty state instead of a bare rail", (
      tester,
    ) async {
      await pump(
        tester,
        const TimelineView(
          groups: [],
          empty: Text('Tell Fitness what is going on.'),
        ),
      );

      expect(find.text('Tell Fitness what is going on.'), findsOneWidget);
    });

    testWidgets('offers Load older only when the caller can page', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(beats: [beat()]),
          ],
        ),
      );
      expect(find.text('Load older'), findsNothing);

      var pages = 0;
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(beats: [beat()]),
          ],
          onLoadOlder: () => pages++,
        ),
      );
      await tester.tap(find.text('Load older'));
      expect(pages, 1);
    });

    testWidgets('a page already in flight cannot be requested again', (
      tester,
    ) async {
      var pages = 0;
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(beats: [beat()]),
          ],
          onLoadOlder: () => pages++,
          isLoadingMore: true,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<TextButton>(find.byType(TextButton));
      expect(button.onPressed, isNull);
      expect(pages, 0);
    });
  });

  group('audio beats', () {
    TimelineBeat audioBeat({
      required TimelineTranscriptStatus status,
      String? transcript,
      String? entryId,
    }) => beat(
      entryId: entryId,
      content: TimelineBeatContent.audio(
        player: const Text('PLAYER'),
        transcript: transcript,
        transcriptStatus: status,
      ),
    );

    testWidgets('a pending transcript keeps the player and says so', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [audioBeat(status: TimelineTranscriptStatus.pending)],
            ),
          ],
        ),
      );

      // The recording is the thing the user made; it must be playable before
      // its words exist.
      expect(find.text('PLAYER'), findsOneWidget);
      expect(find.text('Transcribing…'), findsOneWidget);
    });

    testWidgets('a failed transcript keeps the beat and offers a retry', (
      tester,
    ) async {
      String? retried;
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                audioBeat(
                  status: TimelineTranscriptStatus.failed,
                  entryId: 'audio-9',
                ),
              ],
            ),
          ],
          onRetryTranscript: (id) => retried = id,
        ),
      );

      expect(find.text('PLAYER'), findsOneWidget);
      expect(find.text('Transcription failed'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 'audio-9');
    });

    testWidgets('a stalled transcript says nothing ran, and still retries', (
      tester,
    ) async {
      String? retried;
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                audioBeat(
                  status: TimelineTranscriptStatus.stalled,
                  entryId: 'audio-10',
                ),
              ],
            ),
          ],
          onRetryTranscript: (id) => retried = id,
        ),
      );

      // The retry is the same, but the claim is not: nothing ran, so calling
      // it a failure would send the user hunting a provider error that never
      // happened.
      expect(find.text('Not transcribed'), findsOneWidget);
      expect(find.text('Transcription failed'), findsNothing);
      expect(find.text('PLAYER'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      expect(retried, 'audio-10');
    });

    testWidgets('no retry is offered when the caller cannot honour one', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                audioBeat(
                  status: TimelineTranscriptStatus.failed,
                  entryId: 'audio-9',
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Transcription failed'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('a short transcript renders without a Show more control', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                audioBeat(
                  status: TimelineTranscriptStatus.none,
                  transcript: 'Short.',
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Short.'), findsOneWidget);
      expect(find.text('Show more'), findsNothing);
    });

    testWidgets('a long transcript clamps and expands', (tester) async {
      final long = List.filled(12, 'walked further than yesterday').join(' ');
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                audioBeat(
                  status: TimelineTranscriptStatus.none,
                  transcript: long,
                ),
              ],
            ),
          ],
        ),
      );

      expect(find.text('Show more'), findsOneWidget);
      var text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, 2);

      await tester.tap(find.text('Show more'));
      await tester.pump();

      text = tester.widget<Text>(find.text(long));
      expect(text.maxLines, isNull, reason: 'expanded shows the whole thing');
      expect(find.text('Show less'), findsOneWidget);
    });
  });

  group('degrading content', () {
    testWidgets('a photo beat with no photos falls back to its caption', (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                beat(
                  content: const TimelineBeatContent.photos(
                    photos: [],
                    caption: 'The reveal moment.',
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('The reveal moment.'), findsOneWidget);
    });

    testWidgets('an empty text beat renders no stray line', (tester) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [beat(content: const TimelineBeatContent.text('   '))],
            ),
          ],
        ),
      );

      expect(find.text('   '), findsNothing);
    });

    testWidgets("a custom beat renders the caller's body inside the chrome", (
      tester,
    ) async {
      await pump(
        tester,
        TimelineView(
          groups: [
            TimelineGroup(
              beats: [
                beat(
                  time: '21:40',
                  kindLabel: 'DAILY REFLECTION',
                  glyph: LottiIcons.confirm,
                  accent: const Color(0xFF00FF00),
                  content: const TimelineBeatContent.custom(
                    Text('Mixed · 3 dimensions rated'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      // The escape hatch is what lets a feature add a beat kind without
      // editing the shared component.
      expect(find.text('Mixed · 3 dimensions rated'), findsOneWidget);
      expect(find.text('21:40'), findsOneWidget);
      expect(find.text('DAILY REFLECTION'), findsOneWidget);
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);
    });
  });
}
