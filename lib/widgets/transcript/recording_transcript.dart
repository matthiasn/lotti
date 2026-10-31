import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/transcript/folded_words.dart';
import 'package:lotti/widgets/transcript/transcript_status.dart';
import 'package:material_ui/material_ui.dart';

/// The words under a recording — or an honest account of why they are not
/// there yet — drawn one way on every check-in surface: the Goals rail and
/// charter, the People composer and timeline, and the events rail.
///
/// - [TranscriptStatus.heard]: the words, in [FoldedWords]' tier — folded
///   in a history list, in full where the user is reviewing what they just
///   said ([folded] false).
/// - Anything else: one status line. The glyph carries the news — a spinner
///   while the words are on their way, the warning glyph when they are not
///   coming — beside the one caption label for that state, then *Retry*
///   where something can be asked again, then the host's own [detail] line.
///
/// The recording itself is never withheld for want of words: the host draws
/// it (a player, a take's header) above this.
class RecordingTranscript extends StatelessWidget {
  const RecordingTranscript({
    required this.id,
    required this.status,
    this.transcript,
    this.summary,
    this.detail,
    this.onRetry,
    this.folded = true,
    super.key,
  });

  /// The recording's entry id, naming the keys.
  final String id;
  final TranscriptStatus status;

  /// The words, shown when [status] is [TranscriptStatus.heard].
  final String? transcript;

  /// A one-line summary to lead the folded words with.
  final String? summary;

  /// The host's own explanation under a status line — the provider's
  /// detail on a failure, or the composer's "you can save now".
  final String? detail;

  /// Asks for the words again; offered on [TranscriptStatus.notTranscribed]
  /// and [TranscriptStatus.failed] only.
  final VoidCallback? onRetry;

  /// Whether heard words fold at [FoldedWords.foldedLines].
  final bool folded;

  @override
  Widget build(BuildContext context) {
    if (status == TranscriptStatus.heard) {
      final words = transcript?.trim() ?? '';
      if (words.isEmpty) return const SizedBox.shrink();
      if (folded) {
        return FoldedWords(id: id, words: words, summary: summary);
      }
      return Semantics(
        liveRegion: true,
        child: Text(
          words,
          key: ValueKey('transcript-words-$id'),
          style: FoldedWords.wordsStyle(context),
        ),
      );
    }

    final tokens = context.designTokens;
    final messages = context.messages;
    final missing = status != TranscriptStatus.transcribing;
    final caption = tokens.typography.styles.others.caption;
    final label = switch (status) {
      TranscriptStatus.transcribing => messages.timelineTranscribing,
      TranscriptStatus.notTranscribed => messages.timelineTranscriptMissing,
      _ => messages.timelineTranscriptionFailed,
    };
    final glyphGap = tokens.spacing.step2;
    final detail = this.detail;

    return Column(
      key: ValueKey('transcript-status-$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (missing)
              Icon(
                LottiIcons.warning,
                size: IconSizes.s,
                color: tokens.colors.alert.warning.defaultColor,
              )
            else
              DesignSystemSpinner(
                size: IconSizes.s,
                color: tokens.colors.text.mediumEmphasis,
              ),
            SizedBox(width: glyphGap),
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  style: caption.copyWith(
                    // Missing words are the news, so the line outranks the
                    // explanation under it; waiting stays quiet.
                    color: missing
                        ? tokens.colors.text.highEmphasis
                        : tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
            ),
            if (missing && onRetry != null)
              DesignSystemButton(
                key: ValueKey('transcript-retry-$id'),
                label: messages.timelineRetryTranscription,
                leadingIcon: LottiIcons.refresh,
                variant: DesignSystemButtonVariant.tertiary,
                size: DesignSystemButtonSize.dense,
                alignsLabelToTrailingEdge: true,
                onPressed: onRetry,
              ),
          ],
        ),
        if (detail != null && detail.trim().isNotEmpty)
          Padding(
            // Under the label, not the glyph: the glyph column stays clear.
            padding: EdgeInsetsDirectional.only(
              start: IconSizes.s + glyphGap,
              top: tokens.spacing.step1,
            ),
            child: Text(
              detail,
              key: ValueKey('transcript-detail-$id'),
              style: caption.copyWith(color: tokens.colors.text.mediumEmphasis),
            ),
          ),
      ],
    );
  }
}
