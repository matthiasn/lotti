import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/journal_entities.dart';
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
class PersonTimelineSliver extends ConsumerWidget {
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

    final slots = <Widget Function(BuildContext)>[
      (context) => heading,
      if (timeline.itemCount >= personTimelineFiltersFrom)
        (context) => Padding(
          key: const ValueKey('person-timeline-filter'),
          padding: inset.copyWith(top: tokens.spacing.step3),
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
            highlighted: highlighted.contains(item.id),
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
    this.highlighted = false,
    super.key,
  });

  final PersonTimelineItem item;
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
                            style: tokens.typography.styles.subtitle.subtitle2
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
    final bodyStyle = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final folded = widget.compact && !_expanded;
    final shown = folded
        ? const <TimelineNote>[]
        : (_expanded || widget.compact ? pinned : pinned.take(_folded))
              .toList();
    final toggle = DesignSystemButton(
      key: const ValueKey('person-about-toggle'),
      label: folded
          ? messages.relationshipAboutPinnedCount(pinned.length)
          : _expanded
          ? messages.relationshipAboutShowLess
          : messages.relationshipAboutShowAll(pinned.length),
      trailingIcon: folded ? LottiIcons.expand : null,
      variant: DesignSystemButtonVariant.tertiary,
      size: DesignSystemButtonSize.dense,
      onPressed: () => setState(() => _expanded = !_expanded),
    );
    return Column(
      key: const ValueKey('person-about'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonCardHeader(
          title: messages.relationshipAboutTitle(widget.personName),
          trailing: widget.compact || pinned.length > _folded ? toggle : null,
        ),
        if (folded)
          Padding(
            padding: EdgeInsets.only(top: tokens.spacing.step1),
            child: Text(
              pinned.first.note.entryText?.plainText.trim() ?? '',
              key: const ValueKey('person-about-preview'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyStyle.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        for (final note in shown)
          DsQuietInk(
            key: ValueKey('person-about-${note.id}'),
            onTap: () => widget.onOpen(note.note),
            builder: (context, highlighted) => Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
              child: Text(
                note.note.entryText?.plainText.trim() ?? '',
                style: highlighted
                    ? bodyStyle.copyWith(
                        color: tokens.colors.interactive.enabled,
                      )
                    : bodyStyle,
              ),
            ),
          ),
      ],
    );
  }
}
