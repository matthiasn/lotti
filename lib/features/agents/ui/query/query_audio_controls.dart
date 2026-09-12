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
        if (active)
          _AudioStatus(
            status: audio.status,
            playingLabel: context.messages.queryAudioReading,
          ),
        DesignSystemButton(
          label: busy
              ? audio.status == QueryAudioStatus.preparing
                    ? context.messages.cancelButton
                    : context.messages.queryAudioStop
              : active && audio.status == QueryAudioStatus.failed
              ? context.messages.queryAudioRetry
              : context.messages.queryAudioReadAloud,
          leadingIcon: busy ? LottiIcons.stop : LottiIcons.volume,
          variant: DesignSystemButtonVariant.tertiary,
          onPressed: busy
              ? controller.stop
              : () => controller.speakAnswer(answerId: answerId),
        ),
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
    required this.onOpenEntry,
    required this.onOpenSettings,
    super.key,
  });
  final QueryAudioChatKey chatKey;
  final String actionId;
  final QueryEvidence evidence;
  final JournalAudio audio;
  final VoidCallback onOpenEntry;
  final VoidCallback onOpenSettings;

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
    final status = active ? state.status : QueryAudioStatus.idle;
    final openRecording = switch (status) {
      QueryAudioStatus.missingFile ||
      QueryAudioStatus.unmatched ||
      QueryAudioStatus.tooLarge ||
      QueryAudioStatus.failed => true,
      _ => false,
    };
    final canRetry = switch (status) {
      QueryAudioStatus.missingFile ||
      QueryAudioStatus.unavailable ||
      QueryAudioStatus.failed => true,
      _ => false,
    };
    final fallbackOnly =
        status == QueryAudioStatus.unmatched ||
        status == QueryAudioStatus.tooLarge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (active)
          _AudioStatus(
            status: status,
            playingLabel: range == null
                ? null
                : messages.queryAudioPlaying(
                    _timestamp(range.start),
                    _timestamp(range.end),
                  ),
          ),
        Wrap(
          spacing: tokens.spacing.step2,
          children: [
            if (status == QueryAudioStatus.unavailable)
              DesignSystemButton(
                label: messages.settingsAiTitle,
                leadingIcon: LottiIcons.settings,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: onOpenSettings,
              ),
            if (openRecording)
              DesignSystemButton(
                label: messages.queryAudioOpenRecording,
                leadingIcon: LottiIcons.forward,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: onOpenEntry,
              ),
            if (!fallbackOnly)
              DesignSystemButton(
                label: busy
                    ? status == QueryAudioStatus.preparing
                          ? messages.cancelButton
                          : messages.queryAudioStop
                    : canRetry
                    ? messages.queryAudioRetry
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
          ],
        ),
        if (range == null && !busy && !fallbackOnly)
          Text(
            messages.queryAudioUploadNotice,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }
}

class _AudioStatus extends StatelessWidget {
  const _AudioStatus({required this.status, this.playingLabel});
  final QueryAudioStatus status;
  final String? playingLabel;
  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final label = switch (status) {
      QueryAudioStatus.preparing => messages.queryAudioPreparing,
      QueryAudioStatus.unmatched => messages.queryAudioNoMatch,
      QueryAudioStatus.unavailable => messages.queryAudioSetupRequired,
      QueryAudioStatus.playing => playingLabel,
      QueryAudioStatus.stale => messages.queryAudioStale,
      QueryAudioStatus.missingFile => messages.queryAudioMissingFile,
      QueryAudioStatus.tooLarge => messages.queryAudioTooLarge,
      QueryAudioStatus.failed => messages.queryAudioFailed,
      _ => null,
    };
    return label == null
        ? const SizedBox.shrink()
        : Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.designTokens.typography.styles.others.caption
                      .copyWith(
                        color: context.designTokens.colors.text.mediumEmphasis,
                      ),
                ),
                if (status == QueryAudioStatus.unavailable)
                  Material(
                    type: MaterialType.transparency,
                    child: ExpansionTile(
                      title: Text(
                        messages.queryAudioSetupDetails,
                        style: context
                            .designTokens
                            .typography
                            .styles
                            .others
                            .caption,
                      ),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          messages.queryAudioTimingUnavailable,
                          style: context
                              .designTokens
                              .typography
                              .styles
                              .others
                              .caption,
                        ),
                      ],
                    ),
                  ),
              ],
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
