import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/recording_transcript.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

/// The app's one vertical timeline: a dated rail of beats.
///
/// Extracted from the Events detail view so Events and Goals render the same
/// rail from the same code. Two timelines drifting apart is the failure mode
/// this exists to prevent, so a feature that needs a new beat kind supplies a
/// body through [TimelineBeatContent.custom] rather than editing this file.
///
/// The component owns the chrome and the shared behaviours: the rail, day
/// dividers, folded words, transcription status, the open affordance and
/// the paging tail. Ordering is the caller's — Events reads oldest-first, a
/// goal's check-ins newest-first — because only the caller knows which way its
/// story runs.
class TimelineView extends StatelessWidget {
  const TimelineView({
    required this.groups,
    this.onOpenBeat,
    this.onLoadOlder,
    this.onRetryTranscript,
    this.isLoadingMore = false,
    this.empty,
    super.key,
  });

  final List<TimelineGroup> groups;

  /// Opens a beat's source entry. A beat's own [TimelineBeat.onTap] always
  /// outranks this fallback. When neither applies — this is null or the beat
  /// carries no `entryId`, and the beat has no `onTap` — the row renders as
  /// static and drops its chevron, so the affordance always matches the
  /// behaviour.
  final ValueChanged<String>? onOpenBeat;

  /// Renders the paging tail. Null means the caller is showing everything it
  /// has; a timeline is never allowed to resolve its full history eagerly, so a
  /// long-lived rail should always pass this.
  final VoidCallback? onLoadOlder;

  /// Retries a failed transcription for the given beat entry id.
  final ValueChanged<String>? onRetryTranscript;

  final bool isLoadingMore;

  /// Shown in place of the rail when there are no beats at all. An invitation
  /// belongs here, not an apology — and not a bare spinner.
  final Widget? empty;

  static const double railWidth = 28;
  static const double _plainDotSize = 12;
  static const double _glyphDotSize = 20;
  static const double _glyphSize = 11;
  static const double _connectorWidth = 2;

  bool get _hasBeats => groups.any((group) => group.beats.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    if (!_hasBeats) return empty ?? const SizedBox.shrink();

    // A flat row list, so the connector can run continuously past a day
    // divider instead of restarting at every group.
    final rows = <Widget>[];
    // Position is part of the key, not just the id: one entry can legitimately
    // be linked to the same subject twice, and keying on the id alone made that
    // a duplicate-key crash rather than two rows.
    var position = 0;
    for (final group in groups) {
      if (group.beats.isEmpty) continue;
      final label = group.label;
      if (label != null) {
        rows.add(
          _DayDivider(key: ValueKey('timeline-day-$label'), label: label),
        );
      }
      for (final beat in group.beats) {
        rows.add(
          _TimelineTile(
            key: ValueKey('timeline-beat-${beat.id ?? ''}-$position'),
            beat: beat,
            onOpenBeat: onOpenBeat,
            onRetryTranscript: onRetryTranscript,
          ),
        );
        position++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...rows,
        if (onLoadOlder != null) ...[
          SizedBox(height: tokens.spacing.step2),
          _LoadOlderButton(
            onPressed: isLoadingMore ? null : onLoadOlder,
            isLoading: isLoadingMore,
          ),
        ],
      ],
    );
  }
}

/// A labelled node on the rail — a small dot, an uppercase label and a
/// hairline — rather than a tile, so a day break reads as a marker on the
/// thread and not as another entry.
class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
      child: Row(
        children: [
          SizedBox(
            width: TimelineView.railWidth,
            child: Center(
              child: Container(
                width: tokens.spacing.step1,
                height: tokens.spacing.step1,
                decoration: BoxDecoration(
                  color: cs.outline,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Text(label, style: calmEyebrowStyle(tokens)),
          SizedBox(width: tokens.spacing.step3),
          Expanded(child: Divider(height: 1, color: cs.outlineVariant)),
        ],
      ),
    );
  }
}

class _LoadOlderButton extends StatelessWidget {
  const _LoadOlderButton({required this.onPressed, required this.isLoading});

  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: TextButton(
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: IconSizes.xs,
                height: IconSizes.xs,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(
                context.messages.timelineLoadOlder,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.beat,
    this.onOpenBeat,
    this.onRetryTranscript,
    super.key,
  });

  final TimelineBeat beat;
  final ValueChanged<String>? onOpenBeat;
  final ValueChanged<String>? onRetryTranscript;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final entryId = beat.entryId;
    // A beat's own tap outranks the entry navigation; either way the row is
    // "openable" and earns the chevron.
    final onTap =
        beat.onTap ??
        (onOpenBeat != null && entryId != null
            ? () => onOpenBeat!(entryId)
            : null);
    final canOpen = onTap != null;
    final accent = beat.accent ?? cs.primary;

    final dotSize = beat.glyph == null
        ? TimelineView._plainDotSize
        : TimelineView._glyphDotSize;

    // A Stack, not an IntrinsicHeight: the connector has to span whatever the
    // body turns out to be, and bodies legitimately contain widgets that cannot
    // report an intrinsic height (a transcript measures itself against the
    // width it is given). Asking for intrinsics crashed the moment a beat
    // carried one.
    final row = Stack(
      children: [
        PositionedDirectional(
          start: (TimelineView.railWidth - TimelineView._connectorWidth) / 2,
          top: tokens.spacing.step1 + dotSize,
          bottom: 0,
          width: TimelineView._connectorWidth,
          child: ColoredBox(color: cs.outline),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: TimelineView.railWidth,
              child: Column(
                children: [
                  SizedBox(height: tokens.spacing.step1),
                  _RailDot(glyph: beat.glyph, accent: accent),
                ],
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: tokens.spacing.step5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      // spaceBetween pins the leading labels to the start and
                      // the trailing slot to the end while BOTH stay
                      // shrinkable: a non-flex trailing widget could starve
                      // the time label on narrow cards (large text scales,
                      // longer locales) and overflow the row.
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Row(
                            children: [
                              Text(
                                beat.timeLabel,
                                style: tokens.typography.styles.body.bodySmall
                                    .copyWith(color: cs.onSurfaceVariant),
                              ),
                              if (beat.kindLabel != null) ...[
                                SizedBox(width: tokens.spacing.step2),
                                Flexible(
                                  child: Text(
                                    beat.kindLabel!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: calmEyebrowStyle(
                                      tokens,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Fully right-aligned, on the SAME row as the time
                        // and kind — a status-only beat stays one tight line.
                        // Flexible, so an oversized trailing widget shrinks
                        // instead of pushing the row into overflow.
                        if (beat.trailing != null) ...[
                          SizedBox(width: tokens.spacing.step2),
                          Flexible(child: beat.trailing!),
                        ],
                      ],
                    ),
                    SizedBox(height: tokens.spacing.step2),
                    _TimelineContent(
                      beat: beat,
                      onRetryTranscript: onRetryTranscript,
                    ),
                  ],
                ),
              ),
            ),
            // Pinned to the timestamp line so it reads as a row-level "open",
            // not as paging of whatever the body happens to contain.
            if (canOpen)
              Padding(
                padding: EdgeInsets.only(left: tokens.spacing.step2),
                child: Icon(
                  LottiIcons.chevronRight,
                  size: IconSizes.xs,
                  color: cs.outline,
                ),
              ),
          ],
        ),
      ],
    );

    if (!canOpen) return row;
    // A local transparent Material carries the hover fill: the rail sits on
    // an opaque card, so ink painted on the Scaffold's Material below it
    // never showed and openable rows gave no pointer feedback.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        hoverColor: tokens.colors.surface.hover,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: row,
      ),
    );
  }
}

/// The rail marker. Without a glyph this is the plain dot Events has always
/// drawn, which is what lets Events adopt the shared component with no visual
/// change at all.
class _RailDot extends StatelessWidget {
  const _RailDot({required this.glyph, required this.accent});

  final IconData? glyph;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (glyph == null) {
      return Container(
        width: TimelineView._plainDotSize,
        height: TimelineView._plainDotSize,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
      );
    }
    return Container(
      width: TimelineView._glyphDotSize,
      height: TimelineView._glyphDotSize,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Icon(glyph, size: TimelineView._glyphSize, color: accent),
    );
  }
}

/// Renders a beat's body, degrading rather than crashing on a malformed one: a
/// photo beat that arrived with no photos falls back to its caption, and an
/// empty text beat renders nothing rather than an empty line with a rail dot
/// beside it.
class _TimelineContent extends StatelessWidget {
  const _TimelineContent({required this.beat, this.onRetryTranscript});

  final TimelineBeat beat;
  final ValueChanged<String>? onRetryTranscript;

  static const double _thumbSize = 72;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final styles = tokens.typography.styles;

    switch (beat.content) {
      case final TimelineTextContent text:
        if (text.text.trim().isEmpty) return const SizedBox.shrink();
        // Typed words wear the spoken words' tier and fold: on one rail a
        // note and a recording are the user's words alike.
        return FoldedWords(
          id: beat.entryId ?? beat.id ?? beat.timeLabel,
          words: text.text.trim(),
        );

      case final TimelineCustomContent custom:
        return custom.child;

      case final TimelineTimeSpanContent span:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            span.bar,
            if (span.text case final text? when text.trim().isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step2),
              Text(
                text,
                style: styles.body.bodyLarge.copyWith(color: cs.onSurface),
              ),
            ],
          ],
        );

      case final TimelineAudioContent audio:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            audio.player,
            ..._transcriptSlot(context, audio),
          ],
        );

      case final TimelinePhotosContent photos:
        // A photo beat with no photos degrades to its caption rather than
        // rendering a broken frame.
        if (photos.photos.isEmpty) {
          final caption = photos.caption;
          if (caption == null || caption.trim().isEmpty) {
            return const SizedBox.shrink();
          }
          return Text(
            caption,
            style: styles.body.bodyMedium.copyWith(color: cs.onSurfaceVariant),
          );
        }
        return _PhotoCluster(
          photos: photos.photos,
          caption: photos.caption,
          thumbSize: _thumbSize,
        );
    }
  }

  /// The words under a recording, drawn by the shared [RecordingTranscript]
  /// so a check-in recording reads the same here as on every People surface.
  /// The beat itself is never withheld for want of a transcript: the
  /// recording is the thing the user made, and it plays either way.
  List<Widget> _transcriptSlot(BuildContext context, TimelineAudioContent a) {
    final entryId = beat.entryId;
    final transcript = a.transcript;
    if (a.transcriptStatus == TranscriptStatus.heard &&
        (transcript == null || transcript.trim().isEmpty)) {
      return const [];
    }
    return [
      SizedBox(height: context.designTokens.spacing.step2),
      RecordingTranscript(
        id: entryId ?? beat.id ?? beat.timeLabel,
        status: a.transcriptStatus,
        transcript: transcript,
        onRetry: onRetryTranscript != null && entryId != null
            ? () => onRetryTranscript!(entryId)
            : null,
      ),
    ];
  }
}

/// A lead frame plus a supporting strip — a curated moment rather than a
/// flat contact sheet.
///
/// The lead frame is a wide, short band: its height follows the column's width
/// at [leadAspectRatio], held between [minLeadHeight] and [maxLeadHeight], so
/// a photo reads as a strip on the rail at every width instead of a tall
/// block that pushes the next beat off a phone screen. The caption under it
/// is the photo's one-line summary, held to two lines.
class _PhotoCluster extends StatelessWidget {
  const _PhotoCluster({
    required this.photos,
    required this.caption,
    required this.thumbSize,
  });

  final List<TimelinePhoto> photos;
  final String? caption;
  final double thumbSize;

  /// Width over height of the lead frame.
  static const double leadAspectRatio = 2.4;

  /// The lead frame never grows taller than this on a wide column…
  static const double maxLeadHeight = 180;

  /// …nor shrinks below this on a narrow one.
  static const double minLeadHeight = 96;

  /// The lead frame's height for a column [width] wide.
  static double leadHeightFor(double width) =>
      (width / leadAspectRatio).clamp(minLeadHeight, maxLeadHeight);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cs = context.colorScheme;
    final rest = photos.length > 1
        ? photos.sublist(1)
        : const <TimelinePhoto>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.m),
            child: SizedBox(
              height: leadHeightFor(constraints.maxWidth),
              width: double.infinity,
              child: _Photo(
                photo: photos.first,
                fallback: cs.surfaceContainerHighest,
              ),
            ),
          ),
        ),
        if (rest.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step2),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final photo in rest) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    child: SizedBox(
                      width: thumbSize,
                      height: thumbSize,
                      child: _Photo(
                        photo: photo,
                        fallback: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step2),
                ],
              ],
            ),
          ),
        ],
        if (caption case final text? when text.trim().isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: cs.onSurface,
              fontStyle: FontStyle.italic,
              fontWeight: tokens.typography.weight.semiBold,
            ),
          ),
        ],
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.photo, required this.fallback});

  final TimelinePhoto photo;
  final Color fallback;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: photo.image,
      fit: BoxFit.cover,
      alignment: Alignment(photo.cropX * 2 - 1, 0),
      errorBuilder: (context, error, stackTrace) => ColoredBox(color: fallback),
    );
  }
}
