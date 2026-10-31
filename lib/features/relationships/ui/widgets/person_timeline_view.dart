import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/ds_quiet_ink.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/photo_chrome_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/state/relationship_proposal_providers.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_page_cards.dart';
import 'package:lotti/features/speech/ui/widgets/recording_playback.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/check_in_interaction_icon.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

/// What a person's timeline does when a row is opened.
typedef PersonTimelineActions = ({
  void Function(CheckInEntry checkIn) openCheckIn,
  void Function(JournalEntry note) openNote,
  void Function(JournalEntity entry) openEntry,
  void Function(Task task) openTask,

  /// A long press on a task's row: take it off the person, after asking.
  void Function(Task task) unlinkTask,

  /// *Sort this* on a voice note with words: sort them into check-ins,
  /// notes, meetings or tasks, for review.
  void Function(JournalAudio audio) sortVoiceNote,

  /// *Retry* on a recording whose words never came: ask for them again, as
  /// a goal's rail does.
  void Function(JournalAudio audio) retryTranscript,
});

/// The words a check-in row leads with: the text it was saved with, else its
/// first comment or transcript. Only when nothing it holds has words yet
/// does the newest recording without them say where its words are
/// (`awaiting`), so a fresh dictation
/// never reads as an empty check-in — and a recording still waiting never
/// hides a comment that has words. Null when the check-in holds no words
/// at all (only photos).
({String? text, JournalAudio? awaiting})? checkInSummaryOf(
  CheckInEntry checkIn,
  List<JournalEntity> entries,
) {
  final saved = checkIn.entryText?.plainText.trim() ?? '';
  if (saved.isNotEmpty) return (text: saved, awaiting: null);
  JournalAudio? awaiting;
  for (final entry in entries) {
    if (entry is JournalImage) continue;
    final words = entry.entryText?.plainText.trim() ?? '';
    if (words.isNotEmpty) return (text: words, awaiting: null);
    if (entry is JournalAudio &&
        (awaiting == null ||
            entry.meta.dateFrom.isAfter(awaiting.meta.dateFrom))) {
      awaiting = entry;
    }
  }
  return awaiting == null ? null : (text: null, awaiting: awaiting);
}

/// What a check-in holds, as one quiet line — `2 recordings · 1 photo` — or
/// null when it holds nothing but the text it leads with.
String? checkInHoldsLabelOf(BuildContext context, List<JournalEntity> entries) {
  final messages = context.messages;
  final recordings = entries.whereType<JournalAudio>().length;
  final photos = entries.whereType<JournalImage>().length;
  // A blank comment — started and not yet written — holds nothing.
  final comments = entries
      .whereType<JournalEntry>()
      .where((e) => (e.entryText?.plainText.trim() ?? '').isNotEmpty)
      .length;
  final parts = [
    if (recordings > 0) messages.relationshipCheckInRecordingCount(recordings),
    if (photos > 0) messages.relationshipCheckInPhotoCount(photos),
    if (comments > 0) messages.relationshipCheckInCommentCount(comments),
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// The heading a section wears: *Upcoming*, *Today*, *This week*, or the
/// month — with the year only when it is not this one.
String personTimelineSectionLabel(
  BuildContext context,
  PersonTimelineSection section, {
  required DateTime now,
}) {
  final messages = context.messages;
  return switch (section.kind) {
    PersonTimelineSectionKind.upcoming => messages.relationshipTimelineUpcoming,
    PersonTimelineSectionKind.today => messages.relationshipTimelineToday,
    PersonTimelineSectionKind.thisWeek => messages.relationshipTimelineThisWeek,
    PersonTimelineSectionKind.month => DateFormat(
      section.month!.year == now.year ? 'MMMM' : 'MMMM y',
      Localizations.localeOf(context).toString(),
    ).format(section.month!),
  };
}

String _filterLabel(BuildContext context, PersonTimelineFilter filter) {
  final messages = context.messages;
  return switch (filter) {
    PersonTimelineFilter.all => messages.relationshipTimelineFilterAll,
    PersonTimelineFilter.checkIns => messages.relationshipCheckInsLabel,
    PersonTimelineFilter.notes => messages.relationshipTimelineFilterNotes,
    PersonTimelineFilter.tasks => messages.relationshipLinkedTasksLabel,
    PersonTimelineFilter.photos => messages.relationshipTimelineFilterPhotos,
    PersonTimelineFilter.meetings =>
      messages.relationshipTimelineFilterMeetings,
  };
}

/// A person's timeline as one lazy sliver: the filter (once there is enough
/// to filter), then each section's heading and its rows on one rail.
///
/// An empty timeline teaches instead: one line naming what the page's bar
/// adds, so the first visit says what to do rather than showing a void.
class PersonTimelineSliver extends ConsumerWidget {
  const PersonTimelineSliver({
    required this.timeline,
    required this.personName,
    required this.filter,
    required this.onFilter,
    required this.actions,
    required this.now,
    this.summaries = const {},
    super.key,
  });

  final PersonTimeline timeline;

  /// The line each recording leads with, by recording id — read with the
  /// page's detail, so a row is laid out at its final height the first time.
  final Map<String, String> summaries;
  final String personName;
  final PersonTimelineFilter filter;
  final ValueChanged<PersonTimelineFilter> onFilter;
  final PersonTimelineActions actions;

  /// The device's local time, the reference the sections were cut against.
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // A task just confirmed from the agent's suggestions is marked for a
    // moment, so the reader sees where it landed.
    final highlighted = ref.watch(relationshipTaskHighlightProvider);
    // The sliver is outdented by the rows' own inset (see the page), so a
    // row's tile — and the hover fill behind it — reaches the page's text
    // edge; the heading and the empty state take that inset back.
    final inset = EdgeInsets.symmetric(horizontal: tokens.spacing.step3);
    final heading = Padding(
      key: const ValueKey('person-timeline-heading'),
      padding: inset,
      child: PersonCardHeader(title: messages.relationshipTimelineTitle),
    );
    if (timeline.itemCount == 0) {
      return SliverList.list(
        children: [
          heading,
          Padding(
            padding: inset.copyWith(top: tokens.spacing.step4),
            child: DesignSystemEmptyState(
              key: const ValueKey('person-timeline-empty'),
              icon: LottiIcons.timeline,
              hint: messages.relationshipTimelineEmpty(personName),
            ),
          ),
        ],
      );
    }

    final slots = <_TimelineSlot>[
      _TimelineSlot(heading.key!, (context, key) => heading),
      if (timeline.itemCount >= personTimelineFiltersFrom)
        _TimelineSlot(
          const ValueKey('person-timeline-filter'),
          (context, key) => Padding(
            key: key,
            padding: inset.copyWith(top: tokens.spacing.step2),
            child: DsChoicePills<PersonTimelineFilter>(
              value: filter,
              values: PersonTimelineFilter.values,
              labelFor: (value) => _filterLabel(context, value),
              onSelected: onFilter,
            ),
          ),
        ),
      for (final section in timeline.sections) ...[
        _TimelineSlot(
          ValueKey(
            'person-timeline-section-${section.kind.name}'
            '${section.month?.toIso8601String() ?? ''}',
          ),
          (context, key) => DesignSystemTimelineSectionHeader(
            key: key,
            label: personTimelineSectionLabel(context, section, now: now),
          ),
        ),
        for (final (index, item) in section.items.indexed)
          _TimelineSlot(
            ValueKey('person-timeline-row-${item.id}'),
            (context, key) => PersonTimelineRow(
              key: key,
              item: item,
              summary: switch (item) {
                TimelineVoiceNote(:final audio) => summaries[audio.meta.id],
                TimelineCheckIn(:final entries) =>
                  summaries[entries
                      .whereType<JournalAudio>()
                      .firstOrNull
                      ?.meta
                      .id],
                _ => null,
              },
              last: index == section.items.length - 1,
              highlighted: highlighted.contains(item.id),
              actions: actions,
              now: now,
            ),
          ),
      ],
    ];
    final indexOfKey = {
      for (final (index, slot) in slots.indexed) slot.key: index,
    };

    // A builder list matches children by index unless it can look a key up.
    // Without the lookup, a check-in arriving at the top shifted every row
    // below it to a new index, and each was torn down and built again — its
    // photos re-resolved and re-decoded, a row's opened words folded — on
    // every reload that added or removed a row: the person page flickered
    // after each check-in, twice (the check-in, then its recording moving
    // in). With it, a row keeps its element wherever it moves.
    return SliverList.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        return slot.build(context, slot.key);
      },
      findChildIndexCallback: (key) => indexOfKey[key],
    );
  }
}

/// One child of [PersonTimelineSliver]'s list, built lazily, with the [key]
/// it is built under so the list can find it again after it moves.
class _TimelineSlot {
  const _TimelineSlot(this.key, this.build);

  final Key key;
  final Widget Function(BuildContext context, Key key) build;
}

/// One row of a person's timeline, whatever it holds.
class PersonTimelineRow extends StatelessWidget {
  const PersonTimelineRow({
    required this.item,
    required this.actions,
    required this.now,
    this.summary,
    this.last = false,
    this.highlighted = false,
    super.key,
  });

  final PersonTimelineItem item;

  /// The line a spoken row leads with — the newest summary of the voice
  /// note, or of the recording the check-in holds — when one was written.
  final String? summary;
  final bool highlighted;
  final PersonTimelineActions actions;
  final DateTime now;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    String at(DateTime time) =>
        relationshipTimestampLabelOf(context, time, now: now);
    String day(DateTime time) => relationshipDayLabelOf(context, time);

    final row = switch (item) {
      final TimelineCheckIn row => () {
        final checkIn = row.checkIn;
        final summary = checkInSummaryOf(checkIn, row.entries);
        final duration = relationshipDurationLabelOf(
          context,
          checkIn.meta.dateTo.difference(checkIn.meta.dateFrom),
        );
        return (
          icon: checkInInteractionIcon(checkIn.data.interactionType),
          kind: checkInInteractionLabel(context, checkIn.data.interactionType),
          time: at(checkIn.meta.dateFrom),
          tail: [?duration, ?checkInHoldsLabelOf(context, row.entries)],
          text: summary?.text,
          awaiting: summary?.awaiting,
          footer: _CheckInFooter(checkIn: checkIn),
          onTap: () => actions.openCheckIn(checkIn),
        );
      }(),
      final TimelineNote row => (
        icon: LottiIcons.note,
        kind: messages.relationshipTimelineNote,
        time: at(row.at),
        tail: const <String>[],
        text: row.note.entryText?.plainText.trim(),
        awaiting: null,
        footer: null,
        onTap: () => actions.openNote(row.note),
      ),
      final TimelineVoiceNote row => () {
        final words = row.audio.entryText?.plainText.trim() ?? '';
        return (
          icon: LottiIcons.mic,
          kind: messages.relationshipTimelineVoiceNote,
          time: at(row.at),
          tail: [
            ?relationshipDurationLabelOf(
              context,
              row.audio.data.duration,
            ),
          ],
          text: words.isEmpty ? null : words,
          awaiting: words.isEmpty ? row.audio : null,
          footer: null,
          onTap: () => actions.openEntry(row.audio),
        );
      }(),
      final TimelinePhotos row => (
        icon: LottiIcons.image,
        kind: messages.relationshipCheckInPhotoCount(row.photos.length),
        time: day(row.at),
        tail: const <String>[],
        text: null,
        awaiting: null,
        footer: _PhotoStrip(photos: row.photos, onOpen: actions.openEntry),
        onTap: () => actions.openEntry(row.photos.first),
      ),
      final TimelineTask row => (
        // A task's kind, not a checkbox: the tile marks the row, and a box
        // that looked tickable completed nothing when tapped.
        icon: row.open ? LottiIcons.clipboardText : LottiIcons.factCheck,
        kind: messages.relationshipTimelineTask,
        time: switch (row) {
          TimelineTask(open: true, due: final due?) => _dueLabel(
            context,
            due,
          ),
          TimelineTask(open: false) => messages.relationshipTimelineTaskDoneAt(
            at(row.at),
          ),
          _ => day(row.at),
        },
        tail: const <String>[],
        // An untitled task still says it is one — the words the unlink
        // question uses — rather than a row with nothing to read.
        text: row.task.data.title.trim().isEmpty
            ? messages.taskUntitled
            : row.task.data.title,
        awaiting: null,
        footer: null,
        onTap: () => actions.openTask(row.task),
      ),
      final TimelineMeeting row => (
        icon: LottiIcons.calendar,
        kind: messages.relationshipTimelineMeeting,
        time: _meetingTime(context, row.event),
        tail: [
          if (row.calledOff) messages.relationshipTimelineMeetingCalledOff,
        ],
        text: row.event.data.title,
        awaiting: null,
        footer: null,
        onTap: () => actions.openEntry(row.event),
      ),
    };

    final overdue = switch (item) {
      TimelineTask(open: true, due: final due?) => due.isBefore(
        DateTime(now.year, now.month, now.day),
      ),
      _ => false,
    };
    final metaInk = overdue
        ? tokens.colors.alert.warning.ink
        : tokens.colors.text.mediumEmphasis;
    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: metaInk,
    );
    final text = row.text;
    return DesignSystemTimelineRow(
      leading: DesignSystemTimelineTile(icon: row.icon),
      // Widest first, shedding one segment at a time from the end — what the
      // check-in holds before how long it lasted — so a phone keeps a call's
      // length; the time and the kind survive every width.
      meta: DsTieredText(
        tiers: [
          for (var keep = row.tail.length; keep >= 0; keep--)
            [row.time, row.kind, ...row.tail.take(keep)].join(' · '),
          row.time,
        ],
        style: relationshipTimestampStyle(
          tokens,
          base: tokens.typography.styles.others.caption,
          color: metaInk,
        ),
        tailStyle: metaStyle,
      ),
      body: _withPlayback(_recordingOf(item), switch (item) {
        // A recording whose words are not here yet says where they are the
        // way every check-in recording does — and, past the grace window
        // with nothing on the way, that they are not coming.
        _ when row.awaiting != null => _AwaitedWords(
          recording: row.awaiting!,
          onRetry: () => actions.retryTranscript(row.awaiting!),
        ),
        // A voice note leads with its summary, and opens to its words.
        final TimelineVoiceNote voice => FoldedWords(
          id: voice.audio.meta.id,
          words: voice.audio.entryText?.plainText.trim() ?? '',
          summary: summary,
        ),
        // A check-in leads with the summary of the recording it holds,
        // and opens to its own words.
        final TimelineCheckIn checkIn when text != null && text.isNotEmpty =>
          FoldedWords(
            id: checkIn.checkIn.meta.id,
            words: text,
            summary: summary,
          ),
        _ when text == null || text.isEmpty => null,
        _ => Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: FoldedWords.wordsStyle(context),
        ),
      }),
      footer: row.footer,
      // Words to sort, a way to sort them: a voice note is what a capture
      // stays when it was not filed, and this files it later. Beside the
      // meta line, so the action costs the row no height.
      trailing: switch (item) {
        final TimelineVoiceNote row
            when (row.audio.entryText?.plainText.trim() ?? '').isNotEmpty =>
          DesignSystemButton(
            key: ValueKey('person-sort-${row.audio.meta.id}'),
            label: messages.relationshipSortThis,
            variant: DesignSystemButtonVariant.quiet,
            size: DesignSystemButtonSize.dense,
            onPressed: () => actions.sortVoiceNote(row.audio),
          ),
        _ => null,
      },
      last: last,
      highlighted: highlighted,
      onTap: row.onTap,
      onLongPress: switch (item) {
        final TimelineTask row => () => actions.unlinkTask(row.task),
        _ => null,
      },
      semanticsLabel: messages.relationshipTimelineRowLabel(
        row.kind,
        row.time,
        text ?? '',
      ),
    );
  }

  String _dueLabel(BuildContext context, DateTime due) {
    final messages = context.messages;
    final dueDay = relationshipDayLabelOf(context, due);
    return due.isBefore(DateTime(now.year, now.month, now.day))
        ? messages.relationshipTimelineTaskOverdue(dueDay)
        : messages.relationshipDueDay(dueDay);
  }

  String _meetingTime(BuildContext context, JournalEvent event) {
    final from = event.meta.dateFrom;
    final to = event.meta.dateTo;
    final start = relationshipTimestampLabelOf(context, from, now: now);
    return to.isAfter(from) ? '$start – ${relationshipTimeLabel(to)}' : start;
  }
}

/// Where a recording's words are while it has none, in the shared status:
/// a transcription running or failed says so; otherwise the grace rule.
/// *Retry* asks for them again.
///
/// It wakes itself when its grace window closes (`TranscriptGraceRebuild`),
/// as a goal's rail does: a recording nothing picked up produces no
/// transcript, no status change and no database write, so on a page left
/// open nothing else would ever turn its *Transcribing…* into *Not
/// transcribed*.
class _AwaitedWords extends ConsumerStatefulWidget {
  const _AwaitedWords({required this.recording, required this.onRetry});

  final JournalAudio recording;
  final VoidCallback onRetry;

  @override
  ConsumerState<_AwaitedWords> createState() => _AwaitedWordsState();
}

class _AwaitedWordsState extends ConsumerState<_AwaitedWords>
    with TranscriptGraceRebuild {
  @override
  Widget build(BuildContext context) {
    final id = widget.recording.meta.id;
    final inference = ref.watch(
      inferenceStatusControllerProvider((
        id: id,
        aiResponseType: AiResponseType.audioTranscription,
      )),
    );
    final graceExpiry = widget.recording.meta.dateFrom.add(kTranscriptGrace);
    final now = clock.now();
    final status = transcriptStatusOf(
      hasTranscript: false,
      running: inference == InferenceStatus.running,
      failed: inference == InferenceStatus.error,
      graceExpiry: graceExpiry,
      now: now,
    );
    // Waiting with nothing running is the one state no other rebuild ends.
    armGraceRebuild(
      status == TranscriptStatus.transcribing &&
              inference == InferenceStatus.idle &&
              graceExpiry.isAfter(now)
          ? graceExpiry
          : null,
    );
    return RecordingTranscript(
      id: id,
      status: status,
      onRetry: widget.onRetry,
    );
  }
}

/// The recording a row plays, when it holds one: a voice note's own, or the
/// newest a check-in holds — what a goal's rail plays for a spoken check-in.
JournalAudio? _recordingOf(PersonTimelineItem item) => switch (item) {
  TimelineVoiceNote(:final audio) => audio,
  TimelineCheckIn(:final entries) =>
    entries.whereType<JournalAudio>().fold<JournalAudio?>(
      null,
      (newest, audio) =>
          newest == null || audio.meta.dateFrom.isAfter(newest.meta.dateFrom)
          ? audio
          : newest,
    ),
  _ => null,
};

/// [words] under the row's [recording], played lightly in place
/// ([RecordingPlayback]), as a goal's rail carries its recordings.
Widget? _withPlayback(JournalAudio? recording, Widget? words) =>
    recording == null
    ? words
    : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [RecordingPlayback(recording), ?words],
      );

/// How a check-in felt and what it was about, as one caption line: the
/// feeling's glyph in its colour, then its word — the colour is never the
/// only carrier — then the topics as plain words. *Neutral* says nothing:
/// it is the absence of news, and a pill for it out-shouted the good ones.
class _CheckInFooter extends StatelessWidget {
  const _CheckInFooter({required this.checkIn});

  final CheckInEntry checkIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final sentiment = checkIn.data.sentiment;
    final feeling = sentiment == null || sentiment == CheckInSentiment.neutral
        ? null
        : sentiment;
    final topics = checkIn.data.topics;
    if (feeling == null && topics.isEmpty) return const SizedBox.shrink();
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Row(
      children: [
        if (feeling != null) ...[
          Icon(
            sentimentGlyph(feeling),
            size: IconSizes.s,
            color: sentimentColor(tokens, feeling),
          ),
          SizedBox(width: tokens.spacing.step1),
        ],
        Flexible(
          child: Text(
            [
              if (feeling != null) checkInSentimentLabel(context, feeling),
              ...topics,
            ].join(' · '),
            key: const ValueKey('person-timeline-check-in-footer'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

/// A day's photos as a strip of thumbnails — each opens its own photo — at
/// most four, the last saying how many more there are.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos, required this.onOpen});

  final List<JournalImage> photos;
  final void Function(JournalEntity photo) onOpen;

  static const _shown = 4;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    const size = ControlSizes.mediaThumbnail;
    final more = photos.length - _shown;
    final shown = photos.take(_shown).toList();
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final (index, photo) in shown.indexed)
          GestureDetector(
            key: ValueKey('person-timeline-photo-${photo.meta.id}'),
            // The whole square, picture or not: a thumbnail whose file has not
            // arrived yet draws nothing, and a tap there fell through to the
            // row and opened the day's first photo instead.
            behavior: HitTestBehavior.opaque,
            onTap: () => onOpen(photo),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              child: SizedBox.square(
                dimension: size,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CardImageWidget(
                      journalImage: photo,
                      height: size.round(),
                      fit: BoxFit.cover,
                    ),
                    if (more > 0 && index == shown.length - 1)
                      // Chrome over a photograph: the photo-neutral glass,
                      // legible on any picture in either theme.
                      ColoredBox(
                        color: PhotoNeutralGlass.fill,
                        child: Center(
                          child: Text(
                            '+$more',
                            style: tokens.typography.styles.others.caption
                                .copyWith(color: PhotoNeutralGlass.glyph),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The notes the user pinned about a person — where you met, what they love
/// — under *About {name}*, newest first.
///
/// [compact] (a phone) folds it to one line — the heading, how many notes,
/// and the first one's opening — so the timeline reaches the first screen;
/// opening it shows every note. Otherwise three show and the rest fold
/// behind *Show all*. Renders nothing when nothing is pinned: the empty
/// state lives on the timeline, which teaches how to add one.
class PersonAboutSection extends StatefulWidget {
  const PersonAboutSection({
    required this.personName,
    required this.pinned,
    required this.onOpen,
    this.compact = false,
    super.key,
  });

  final String personName;
  final List<TimelineNote> pinned;
  final void Function(JournalEntry note) onOpen;
  final bool compact;

  @override
  State<PersonAboutSection> createState() => _PersonAboutSectionState();
}

class _PersonAboutSectionState extends State<PersonAboutSection> {
  static const _folded = 3;
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final pinned = widget.pinned;
    if (pinned.isEmpty) return const SizedBox.shrink();
    final tokens = context.designTokens;
    final messages = context.messages;
    final bodyStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final title = messages.relationshipAboutTitle(widget.personName);
    // On a phone, folded, the section is its heading alone — one line that
    // opens in place — so the page above the timeline holds one thing that
    // leads, not another block of text.
    if (widget.compact && !_expanded) {
      return DsQuietInk(
        key: const ValueKey('person-about'),
        onTap: () => setState(() => _expanded = true),
        builder: (context, highlighted) => Semantics(
          button: true,
          label: '$title · ${messages.relationshipAboutShowAll(pinned.length)}',
          excludeSemantics: true,
          child: Padding(
            key: const ValueKey('person-about-toggle'),
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
            child: PersonCardHeader(
              title: title,
              count: pinned.length,
              countKey: const ValueKey('person-about-count'),
              trailing: Icon(
                LottiIcons.expand,
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ),
      );
    }
    // A wide pane shows the first three in full, the page's one disclosure
    // opening the rest.
    final foldAt = widget.compact ? 0 : _folded;
    final folded = !_expanded && pinned.length > foldAt;
    final shown = folded ? pinned.take(foldAt) : pinned;
    final oneLine = widget.compact && folded;
    return Column(
      key: const ValueKey('person-about'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonCardHeader(
          title: title,
          count: pinned.length,
          countKey: const ValueKey('person-about-count'),
        ),
        for (final note in shown)
          DsQuietInk(
            key: ValueKey('person-about-${note.id}'),
            onTap: () => widget.onOpen(note.note),
            builder: (context, highlighted) => Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step1),
              child: Text(
                note.note.entryText?.plainText.trim() ?? '',
                maxLines: oneLine ? 1 : null,
                overflow: oneLine ? TextOverflow.ellipsis : null,
                style: highlighted
                    ? bodyStyle.copyWith(
                        color: tokens.colors.interactive.enabled,
                      )
                    : bodyStyle,
              ),
            ),
          ),
        if (pinned.length > foldAt)
          personDisclosure(
            context,
            key: const ValueKey('person-about-toggle'),
            open: _expanded,
            label: _expanded
                ? messages.relationshipAboutShowLess
                : messages.relationshipAboutShowAll(pinned.length),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}
