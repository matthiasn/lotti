import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
import 'package:lotti/features/design_system/components/timeline/design_system_timeline_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme_text_styles.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

/// The event's timeline: what was linked to it — photos, notes, recordings,
/// recorded time — oldest first, one [DesignSystemTimelineRow] each.
///
/// The same row the goal and person timelines hang on their rails, so an
/// event's history reads like theirs: a neutral tile naming the kind, a
/// `time · kind` meta line, the words at a reading measure, and the row
/// itself as the door to its entry. What stays the event's own is the photo:
/// a photo row carries the picture as a wide, short band in its footer, with
/// its one-line caption under it, because an event's timeline is
/// photo-led where a person's is mostly words.
///
/// Rows open their source entry through [onOpenEntry]; with it null, or for
/// a row without an entry id, the row is inert.
class EventTimeline extends StatelessWidget {
  const EventTimeline({required this.entries, this.onOpenEntry, super.key});

  final List<EventTimelineEntry> entries;

  /// Opens a row's source entry (receives the entry id).
  final ValueChanged<String>? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in entries.indexed)
          _EventTimelineRow(
            key: ValueKey('event-timeline-row-$index'),
            entry: entry,
            last: index == entries.length - 1,
            onOpenEntry: onOpenEntry,
          ),
      ],
    );
  }
}

class _EventTimelineRow extends StatelessWidget {
  const _EventTimelineRow({
    required this.entry,
    required this.last,
    required this.onOpenEntry,
    super.key,
  });

  final EventTimelineEntry entry;
  final bool last;
  final ValueChanged<String>? onOpenEntry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final text = entry.text?.trim();
    final words = text == null || text.isEmpty ? null : text;
    final id = entry.entryId ?? entry.timeLabel;
    final span = _spanOf(entry);

    final (IconData icon, String kind) = switch (entry.kind) {
      EventTimelineKind.photo => (
        LottiIcons.image,
        messages.eventsTimelinePhoto,
      ),
      EventTimelineKind.note => (LottiIcons.note, messages.eventsTimelineNote),
      // A recording without a well-formed span reads as the note it is.
      EventTimelineKind.timeRecording when span == null => (
        LottiIcons.note,
        messages.eventsTimelineNote,
      ),
      EventTimelineKind.timeRecording => (
        LottiIcons.timer,
        messages.eventsTimelineTimeRecording,
      ),
      EventTimelineKind.audio => (LottiIcons.mic, messages.eventsVoiceNote),
    };

    final body = switch (entry.kind) {
      EventTimelineKind.photo => null,
      EventTimelineKind.note =>
        words == null ? null : FoldedWords(id: id, words: words),
      EventTimelineKind.timeRecording => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          ?span,
          if (words != null) ...[
            if (span != null) SizedBox(height: tokens.spacing.step2),
            FoldedWords(id: id, words: words),
          ],
        ],
      ),
      EventTimelineKind.audio => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Production always supplies the light playback; this static
          // stand-in is what fixtures and screenshot harnesses render, so a
          // recording still says it exists.
          entry.player ??
              _AudioPlaceholder(
                label: entry.durationLabel ?? messages.eventsVoiceNote,
              ),
          if (words != null) ...[
            SizedBox(height: tokens.spacing.step2),
            RecordingTranscript(
              id: id,
              status: TranscriptStatus.heard,
              transcript: words,
            ),
          ],
        ],
      ),
    };

    final footer = entry.kind == EventTimelineKind.photo
        ? _PhotoFooter(photos: entry.photos, caption: words)
        : null;

    final entryId = entry.entryId;
    final open = onOpenEntry;
    return DesignSystemTimelineRow(
      leading: DesignSystemTimelineTile(icon: icon),
      meta: DsTieredText(
        tiers: ['${entry.timeLabel} · $kind'],
        style: tokens.typography.styles.others.caption.copyWith(
          fontFeatures: dateFigureFontFeatures,
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
      semanticsLabel: '$kind, ${entry.timeLabel}',
      body: body,
      footer: footer,
      onTap: open == null || entryId == null ? null : () => open(entryId),
      last: last,
    );
  }

  /// The span bar of a well-formed time recording, or null when the
  /// recording lacks its end or duration label.
  static Widget? _spanOf(EventTimelineEntry entry) {
    if (entry.kind != EventTimelineKind.timeRecording) return null;
    final end = entry.endTimeLabel;
    final duration = entry.durationLabel;
    if (end == null || end.isEmpty || duration == null || duration.isEmpty) {
      return null;
    }
    return TimeSpanBar(
      startLabel: entry.timeLabel,
      endLabel: end,
      durationLabel: duration,
    );
  }
}

/// A photo row's footer: each picture as a wide, short band, then the
/// photo's one-line caption.
class _PhotoFooter extends StatelessWidget {
  const _PhotoFooter({required this.photos, required this.caption});

  final List<EventPhoto> photos;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, photo) in photos.indexed) ...[
          if (index > 0) SizedBox(height: tokens.spacing.step2),
          EventTimelinePhotoBand(photo: photo),
        ],
        if (caption case final text?) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontStyle: FontStyle.italic,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ],
    );
  }
}

/// One photo on the event's timeline as a wide, short band.
///
/// Its height follows the column's width at [aspectRatio], held between
/// [minHeight] and [maxHeight], so a photo reads as a strip on the rail at
/// every width instead of a tall block that pushes the next row off a phone
/// screen. A picture that fails to load leaves a neutral fill.
class EventTimelinePhotoBand extends StatelessWidget {
  const EventTimelinePhotoBand({required this.photo, super.key});

  final EventPhoto photo;

  /// Width over height of the band.
  static const double aspectRatio = 2.4;

  /// The band never grows taller than this on a wide column…
  static const double maxHeight = 180;

  /// …nor shrinks below this on a narrow one.
  static const double minHeight = 96;

  /// The band's height for a column [width] wide.
  static double heightFor(double width) =>
      (width / aspectRatio).clamp(minHeight, maxHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final fallback = tokens.colors.background.level03;
    return LayoutBuilder(
      builder: (context, constraints) => ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: SizedBox(
          height: heightFor(constraints.maxWidth),
          width: double.infinity,
          child: Image(
            image: photo.image,
            fit: BoxFit.cover,
            alignment: Alignment(photo.cropX * 2 - 1, 0),
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: fallback),
          ),
        ),
      ),
    );
  }
}

/// The non-interactive stand-in shown when no player was resolved.
class _AudioPlaceholder extends StatelessWidget {
  const _AudioPlaceholder({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LottiIcons.playCircled,
          size: IconSizes.s,
          color: tokens.colors.interactive.enabled,
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}
