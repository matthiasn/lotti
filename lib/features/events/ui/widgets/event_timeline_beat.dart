import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/journal/ui/widgets/time_span_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/timeline/timeline_models.dart';

/// Adapts one event beat to the shared timeline's vocabulary.
///
/// The presentation split is deliberate: `eventTimelineEntryFor` stays a pure,
/// widget-free mapping that tests can drive without a `BuildContext`, and this
/// is the thin layer where the pieces that genuinely need one — the localized
/// voice-note fallback, the span bar — get built.
///
/// Events pass no glyph and no accent, so the rail keeps the plain primary dot
/// it has always drawn: adopting the shared component changes how an event
/// looks only where it gains something, which is real playback on a voice memo.
TimelineBeat eventTimelineBeat(BuildContext context, EventTimelineEntry entry) {
  return TimelineBeat(
    id: entry.entryId,
    entryId: entry.entryId,
    timeLabel: entry.timeLabel,
    content: _content(context, entry),
  );
}

TimelineBeatContent _content(BuildContext context, EventTimelineEntry entry) {
  switch (entry.kind) {
    case EventTimelineKind.photo:
      return TimelineBeatContent.photos(
        photos: [
          for (final photo in entry.photos)
            TimelinePhoto(photo.image, cropX: photo.cropX),
        ],
        caption: entry.text,
      );

    case EventTimelineKind.note:
      return TimelineBeatContent.text(entry.text ?? '');

    case EventTimelineKind.timeRecording:
      final endLabel = entry.endTimeLabel;
      final durationLabel = entry.durationLabel;
      // A well-formed recording carries both span labels; without them fall
      // back to a plain note rather than a blank span bar.
      if (endLabel == null ||
          endLabel.isEmpty ||
          durationLabel == null ||
          durationLabel.isEmpty) {
        return TimelineBeatContent.text(entry.text ?? '');
      }
      return TimelineBeatContent.timeSpan(
        bar: TimeSpanBar(
          startLabel: entry.timeLabel,
          endLabel: endLabel,
          durationLabel: durationLabel,
        ),
        text: entry.text,
      );

    case EventTimelineKind.audio:
      return TimelineBeatContent.audio(
        // Without a resolved player the beat still has to say a recording
        // exists, and keep its transcript: dropping either would lose what the
        // user actually made. Production always supplies the real player; this
        // static stand-in is what fixtures and screenshot harnesses render.
        player:
            entry.player ??
            _AudioPlaceholder(
              label: entry.durationLabel ?? context.messages.eventsVoiceNote,
            ),
        transcript: entry.text,
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
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LottiIcons.playCircled, size: IconSizes.s, color: cs.primary),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
