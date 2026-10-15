import 'package:intl/intl.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/list_cards/card_image_widget.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/ui/shared/ds_choice_pills.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/check_in_interaction_icon.dart';
import 'package:material_ui/material_ui.dart';

/// What a person's timeline does when a row is opened.
typedef PersonTimelineActions = ({
  void Function(CheckInEntry checkIn) openCheckIn,
  void Function(JournalEntry note) openNote,
  void Function(JournalEntity entry) openEntry,
  void Function(Task task) openTask,

  /// A long press on a task's row: take it off the person, after asking.
  void Function(Task task) unlinkTask,
});

/// The words a check-in row leads with: the text it was saved with, else its
/// first comment or transcript. Only when nothing it holds has words yet
/// does a recording without them say so (`pending`), so a fresh dictation
/// never reads as an empty check-in — and a recording still waiting never
/// hides a comment that has words. Null when the check-in holds no words
/// at all (only photos).
({String text, bool pending})? checkInSummaryOf(
  BuildContext context,
  CheckInEntry checkIn,
  List<JournalEntity> entries,
) {
  final saved = checkIn.entryText?.plainText.trim() ?? '';
  if (saved.isNotEmpty) return (text: saved, pending: false);
  var awaitingWords = false;
  for (final entry in entries) {
    if (entry is JournalImage) continue;
    final words = entry.entryText?.plainText.trim() ?? '';
    if (words.isNotEmpty) return (text: words, pending: false);
    if (entry is JournalAudio) awaitingWords = true;
  }
  return awaitingWords
      ? (text: context.messages.checkInTranscribingLabel, pending: true)
      : null;
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
class PersonTimelineSliver extends StatelessWidget {
  const PersonTimelineSliver({
    required this.timeline,
    required this.personName,
    required this.filter,
    required this.onFilter,
    required this.actions,
    required this.now,
    super.key,
  });

  final PersonTimeline timeline;
  final String personName;
  final PersonTimelineFilter filter;
  final ValueChanged<PersonTimelineFilter> onFilter;
  final PersonTimelineActions actions;

  /// The device's local time, the reference the sections were cut against.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (timeline.itemCount == 0) {
      return SliverToBoxAdapter(
        child: Padding(
          key: const ValueKey('person-timeline-empty'),
          padding: EdgeInsets.all(tokens.spacing.step3),
          child: Text(
            context.messages.relationshipTimelineEmpty(personName),
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
      );
    }

    final slots = <Widget Function(BuildContext)>[
      if (timeline.itemCount >= personTimelineFiltersFrom)
        (context) => Padding(
          key: const ValueKey('person-timeline-filter'),
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step3,
            0,
            tokens.spacing.step3,
            tokens.spacing.step2,
          ),
          child: DsChoicePills<PersonTimelineFilter>(
            value: filter,
            values: PersonTimelineFilter.values,
            labelFor: (value) => _filterLabel(context, value),
            onSelected: onFilter,
          ),
        ),
      for (final section in timeline.sections) ...[
        (context) => DesignSystemTimelineSectionHeader(
          key: ValueKey(
            'person-timeline-section-${section.kind.name}'
            '${section.month?.toIso8601String() ?? ''}',
          ),
          label: personTimelineSectionLabel(context, section, now: now),
        ),
        for (final (index, item) in section.items.indexed)
          (context) => PersonTimelineRow(
            key: ValueKey('person-timeline-row-${item.id}'),
            item: item,
            last: index == section.items.length - 1,
            actions: actions,
            now: now,
          ),
      ],
    ];

    return SliverList.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) => slots[index](context),
    );
  }
}

/// One row of a person's timeline, whatever it holds.
class PersonTimelineRow extends StatelessWidget {
  const PersonTimelineRow({
    required this.item,
    required this.actions,
    required this.now,
    this.last = false,
    super.key,
  });

  final PersonTimelineItem item;
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

    final ({
      IconData icon,
      String kind,
      String time,
      List<String> tail,
      String? text,
      bool pending,
      Widget? footer,
      VoidCallback onTap,
    })
    row = switch (item) {
      final TimelineCheckIn row => () {
        final checkIn = row.checkIn;
        final summary = checkInSummaryOf(context, checkIn, row.entries);
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
          pending: summary?.pending ?? false,
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
        pending: false,
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
          text: words.isEmpty ? messages.checkInTranscribingLabel : words,
          pending: words.isEmpty,
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
        pending: false,
        footer: _PhotoStrip(photos: row.photos),
        onTap: () => actions.openEntry(row.photos.first),
      ),
      final TimelineTask row => (
        icon: row.open
            ? LottiIcons.checkboxUnchecked
            : LottiIcons.checkboxChecked,
        kind: messages.relationshipTimelineTask,
        time: switch (row) {
          TimelineTask(open: true, due: final due?) => _dueLabel(
            context,
            due,
          ),
          TimelineTask(open: false) => messages.relationshipTimelineTaskDone,
          _ => day(row.at),
        },
        tail: const <String>[],
        text: row.task.data.title,
        pending: false,
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
        pending: false,
        footer: null,
        onTap: () => actions.openEntry(row.event),
      ),
    };

    final metaStyle = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    final text = row.text;
    return DesignSystemTimelineRow(
      leading: DesignSystemTimelineTile(icon: row.icon),
      // Widest first, shedding a whole segment at a time: the time and the
      // kind survive every width.
      meta: DsTieredText(
        tiers: [
          [row.time, row.kind, ...row.tail].join(' · '),
          if (row.tail.isNotEmpty) '${row.time} · ${row.kind}',
          row.time,
        ],
        style: relationshipTimestampStyle(
          tokens,
          base: tokens.typography.styles.others.caption,
          color: tokens.colors.text.mediumEmphasis,
        ),
        tailStyle: metaStyle,
      ),
      body: text == null || text.isEmpty
          ? null
          : Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: row.pending
                  ? metaStyle.copyWith(color: tokens.colors.text.lowEmphasis)
                  : tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
            ),
      footer: row.footer,
      last: last,
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

/// A day's photos as a strip of thumbnails, at most four and a count.
class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({required this.photos});

  final List<JournalImage> photos;

  static const _shown = 4;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final size = tokens.spacing.step10;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        for (final photo in photos.take(_shown))
          ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.s),
            child: SizedBox.square(
              dimension: size,
              child: CardImageWidget(
                journalImage: photo,
                height: size.round(),
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }
}

/// The notes the user pinned about a person — where you met, what they love
/// — under *About {name}*, newest first. Three show; the rest fold behind
/// *Show all*. Renders nothing when nothing is pinned: the empty state lives
/// on the timeline, which teaches how to add one.
class PersonAboutSection extends StatefulWidget {
  const PersonAboutSection({
    required this.personName,
    required this.pinned,
    required this.onOpen,
    super.key,
  });

  final String personName;
  final List<TimelineNote> pinned;
  final void Function(JournalEntry note) onOpen;

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
    final shown = _expanded ? pinned : pinned.take(_folded).toList();
    return Column(
      key: const ValueKey('person-about'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignSystemTimelineSectionHeader(
          label: messages.relationshipAboutTitle(widget.personName),
        ),
        for (final note in shown)
          Semantics(
            button: true,
            child: InkWell(
              key: ValueKey('person-about-${note.id}'),
              borderRadius: BorderRadius.circular(tokens.radii.m),
              onTap: () => widget.onOpen(note.note),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.step3,
                  vertical: tokens.spacing.step2,
                ),
                child: Text(
                  note.note.entryText?.plainText.trim() ?? '',
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                  ),
                ),
              ),
            ),
          ),
        if (pinned.length > _folded)
          DesignSystemButton(
            key: const ValueKey('person-about-toggle'),
            label: _expanded
                ? messages.relationshipAboutShowLess
                : messages.relationshipAboutShowAll(pinned.length),
            variant: DesignSystemButtonVariant.tertiary,
            alignsLabelToLeadingEdge: true,
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
      ],
    );
  }
}
