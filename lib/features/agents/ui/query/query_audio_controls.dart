import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_audio_controller.dart';
import 'package:lotti/features/agents/query/query_audio_excerpt.dart';
import 'package:lotti/features/agents/query/query_journal_crawler.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Explicit playback of a saved answer through the existing local TTS engine.
class QueryAnswerSpeechButton extends ConsumerWidget {
  const QueryAnswerSpeechButton({
    required this.chatKey,
    required this.answerId,
    super.key,
  });
  final QueryAudioChatKey chatKey;
  final String answerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value != true) {
      return const SizedBox.shrink();
    }
    final audio = ref.watch(queryAudioControllerProvider(chatKey));
    final controller = ref.read(queryAudioControllerProvider(chatKey).notifier);
    final active = audio.actionId == answerId;
    final busy = active && audio.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignSystemButton(
          label: busy
              ? context.messages.queryAudioStop
              : context.messages.queryAudioReadAloud,
          leadingIcon: busy ? LottiIcons.stop : LottiIcons.volume,
          variant: DesignSystemButtonVariant.tertiary,
          onPressed: busy
              ? controller.stop
              : () => controller.speakAnswer(answerId: answerId),
        ),
        if (active) _AudioStatus(status: audio.status),
      ],
    );
  }
}

/// Timing generation is an explicit action: opening a quote never uploads a
/// recording. Existing timings can be played without an inference provider.
class QueryEvidenceAudioControls extends ConsumerWidget {
  const QueryEvidenceAudioControls({
    required this.chatKey,
    required this.actionId,
    required this.evidence,
    required this.audio,
    super.key,
  });
  final QueryAudioChatKey chatKey;
  final String actionId;
  final QueryEvidence evidence;
  final JournalAudio audio;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final state = ref.watch(queryAudioControllerProvider(chatKey));
    final controller = ref.read(queryAudioControllerProvider(chatKey).notifier);
    final active = state.actionId == actionId;
    final busy = active && state.busy;
    final timing = audio.data.transcriptTimings[evidence.fingerprint];
    final excerpt = timing == null
        ? null
        : queryAudioExcerpt(
            evidence: evidence,
            timing: timing,
            duration: audio.data.duration,
          );
    final current =
        QuerySourceDocument.fromEntry(audio)?.fingerprint ==
            evidence.fingerprint &&
        audio.meta.categoryId == evidence.source.categoryId;
    if (audio.meta.deletedAt != null || (!current && excerpt == null)) {
      return const SizedBox.shrink();
    }
    final range = active && state.status == QueryAudioStatus.stale
        ? null
        : active
        ? state.excerpt ?? excerpt
        : excerpt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DesignSystemButton(
          label: busy
              ? messages.queryAudioStop
              : range == null
              ? messages.queryAudioPrepare
              : messages.queryAudioListen(
                  _timestamp(range.start),
                  _timestamp(range.end),
                ),
          leadingIcon: busy ? LottiIcons.stop : LottiIcons.play,
          variant: DesignSystemButtonVariant.tertiary,
          onPressed: busy
              ? controller.stop
              : () => controller.playEvidence(
                  actionId: actionId,
                  evidence: evidence,
                  generate: range == null,
                ),
        ),
        if (range == null && !busy)
          Text(
            messages.queryAudioUploadNotice,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        if (active) _AudioStatus(status: state.status),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }
}

class _AudioStatus extends StatelessWidget {
  const _AudioStatus({required this.status});
  final QueryAudioStatus status;
  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final label = switch (status) {
      QueryAudioStatus.preparing => messages.queryAudioPreparing,
      QueryAudioStatus.unmatched => messages.queryAudioNoMatch,
      QueryAudioStatus.unavailable => messages.queryAudioTimingUnavailable,
      QueryAudioStatus.stale => messages.queryAudioStale,
      QueryAudioStatus.missingFile => messages.queryAudioMissingFile,
      QueryAudioStatus.tooLarge => messages.queryAudioTooLarge,
      QueryAudioStatus.failed => messages.queryAudioFailed,
      _ => null,
    };
    return label == null
        ? const SizedBox.shrink()
        : Text(
            label,
            style: context.designTokens.typography.styles.others.caption
                .copyWith(
                  color: context.designTokens.colors.text.mediumEmphasis,
                ),
          );
  }
}

String _timestamp(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
