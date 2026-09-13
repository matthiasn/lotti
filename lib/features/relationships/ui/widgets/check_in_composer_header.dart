import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/shared/persona_avatar.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// The composer's heading (design 2026-09-13): the person's avatar, the
/// title, and **one status line** — `with Pip · last spoke Sat 1 Aug` at
/// rest, and while speech is in flight what the field is doing, in the
/// semantic colour of that phase (`● Recording`, `Transcribing…`,
/// `Transcript not received`). Sits in the sheet's pinned toolbar slot, so
/// it stays put while the form scrolls.
///
/// Reads the phase from the form's [CheckInFormHandle], the same channel the
/// pinned action bar reads Save through, so the header and the field can
/// never disagree about what is happening.
class CheckInComposerHeader extends ConsumerWidget {
  const CheckInComposerHeader({
    required this.relationshipId,
    required this.handle,
    required this.title,
    super.key,
  });

  final String relationshipId;
  final CheckInFormHandle handle;
  final String title;

  /// The toolbar height Wolt reserves: between the header's paddings, the
  /// avatar or the two text lines, whichever is taller at the reader's
  /// text scale — a large-text setting must not clip the status line.
  /// Spelled out as its parts so it moves with the tokens, and taken from
  /// the same [scaler] by the sheet and the header so they never disagree.
  static double height(DsTokens tokens, TextScaler scaler) {
    final lines = scaler.scale(
      tokens.typography.lineHeight.heading3 +
          tokens.typography.lineHeight.bodySmall,
    );
    return tokens.spacing.step4 +
        math.max(tokens.spacing.step8, lines) +
        tokens.spacing.step4;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final detail = ref
        .watch(relationshipDetailControllerProvider(relationshipId))
        .value;
    final relationship = detail?.relationship;
    final data = relationship?.data;
    final name = data?.nickname ?? data?.title;
    final lastSpoke = detail?.checkIns.firstOrNull?.meta.dateFrom;

    return Container(
      width: double.infinity,
      height: height(tokens, MediaQuery.textScalerOf(context)),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (relationship != null && data != null)
            PersonaAvatar(
              initial: personaInitial(data.title),
              id: relationship.meta.id,
              imageId: data.avatarImageId,
              crop: data.avatarCrop,
              size: tokens.spacing.step8,
            )
          else
            SizedBox.square(dimension: tokens.spacing.step8),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              header: true,
              namesRoute: true,
              scopesRoute: true,
              label: title,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      title,
                      style: ModalUtils.modalTitleStyle(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: handle,
                    builder: (context, _) => _StatusLine(
                      status: handle.status,
                      name: name,
                      lastSpoke: lastSpoke,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          IconButton(
            key: const ValueKey('check-in-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            padding: EdgeInsets.all(tokens.spacing.step3),
            icon: Icon(
              LottiIcons.close,
              size: IconSizes.l,
              color: tokens.colors.text.mediumEmphasis,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// The header's second line: who and when at rest, what is happening
/// during speech.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.status,
    required this.name,
    required this.lastSpoke,
  });

  final CheckInComposerStatus status;
  final String? name;
  final DateTime? lastSpoke;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final quiet = tokens.colors.text.mediumEmphasis;
    final accent = tokens.colors.interactive.enabled;

    final (Widget? leading, String label, Color color) = switch (status) {
      CheckInComposerStatus.idle || CheckInComposerStatus.preparing => (
        null,
        switch ((name, lastSpoke)) {
          (null, _) => '',
          (final name?, null) => messages.checkInComposerSubtitleNoContact(
            name,
          ),
          (final name?, final at?) => messages.checkInComposerSubtitle(
            name,
            relationshipDayLabelOf(context, at),
          ),
        },
        quiet,
      ),
      CheckInComposerStatus.recording => (
        _Dot(color: tokens.colors.alert.error.defaultColor),
        messages.checkInStatusRecording,
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.paused => (
        _Dot(color: quiet),
        messages.checkInStatusPaused,
        quiet,
      ),
      CheckInComposerStatus.transcribing => (
        DesignSystemSpinner(
          style: DesignSystemSpinnerStyle.plain,
          size: IconSizes.s,
          strokeWidth: tokens.spacing.step1,
        ),
        messages.checkInTranscribingLabel,
        accent,
      ),
      CheckInComposerStatus.transcriptMissing => (
        Icon(
          LottiIcons.warning,
          size: IconSizes.s,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        messages.checkInStatusTranscriptMissing,
        tokens.colors.alert.warning.ink,
      ),
      CheckInComposerStatus.transcriptionUnavailable => (
        Icon(
          LottiIcons.warning,
          size: IconSizes.s,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        messages.checkInStatusTranscriptionUnavailable,
        tokens.colors.alert.warning.ink,
      ),
      CheckInComposerStatus.microphoneDenied => (
        Icon(
          LottiIcons.micIdle,
          size: IconSizes.s,
          color: tokens.colors.alert.error.defaultColor,
        ),
        messages.checkInStatusMicrophoneDenied,
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.recordingFailed => (
        Icon(
          LottiIcons.micIdle,
          size: IconSizes.s,
          color: tokens.colors.alert.error.defaultColor,
        ),
        messages.checkInStatusRecordingFailed,
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.recordingNotSaved => (
        Icon(
          LottiIcons.micIdle,
          size: IconSizes.s,
          color: tokens.colors.alert.error.defaultColor,
        ),
        messages.checkInStatusRecordingNotSaved,
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.recorderBusy => (
        Icon(
          LottiIcons.mic,
          size: IconSizes.s,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        messages.checkInStatusRecorderBusy,
        tokens.colors.alert.warning.ink,
      ),
    };

    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          if (leading != null) ...[
            leading,
            SizedBox(width: tokens.spacing.step2),
          ],
          Flexible(
            child: Text(
              label,
              key: const ValueKey('check-in-composer-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: IconSizes.xs,
    height: IconSizes.xs,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
