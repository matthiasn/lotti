import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/captions/ds_tiered_text.dart';
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
    this.titleLines = 1,
    super.key,
  });

  final String relationshipId;
  final CheckInFormHandle handle;
  final String title;

  /// How many lines the title takes, measured by the sheet with
  /// [titleLinesFor] against the modal's real width — the same number it
  /// reserves the toolbar with, so the two cannot disagree.
  final int titleLines;

  /// Above this text scale the avatar leaves the header; the same bar the
  /// modal action bar stacks its actions at.
  static const double largeTextScale = TextScales.large;

  /// How many lines [title] needs at [width]: one at ordinary text scales,
  /// and above the large-text bar as many as it wraps to, capped at two —
  /// measured, so the toolbar reserves exactly what the title takes rather
  /// than a blank band under a title that happened to fit.
  static int titleLinesFor({
    required String title,
    required TextStyle style,
    required TextScaler scaler,
    required DsTokens tokens,
    required double width,
    required TextDirection direction,
  }) {
    if (scaler.scale(1) <= largeTextScale) return 1;
    // The header's own insets, the close control and the gap before it.
    final available =
        width -
        tokens.spacing.step5 * 2 -
        TapTargets.minimum -
        tokens.spacing.step4;
    final painter = TextPainter(
      text: TextSpan(text: title, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 2,
    )..layout(maxWidth: math.max(0, available));
    return painter.computeLineMetrics().length.clamp(1, 2);
  }

  /// The toolbar height Wolt reserves: between the header's paddings, the
  /// avatar or the text lines, whichever is taller at the reader's text
  /// scale — a large-text setting must not clip the status line.
  /// The top padding is the deeper one: on a phone the sheet draws its drag
  /// handle across the top of this slot, and the title has to sit clear of
  /// it. Spelled out as its parts so it moves with the tokens, and taken
  /// from the same [scaler] by the sheet and the header so they never
  /// disagree.
  static double height(
    DsTokens tokens,
    TextScaler scaler, {
    int titleLines = 1,
  }) {
    // Each line as the text engine will lay it out — the style's own font
    // size times its height multiplier, scaled, rounded up to the pixel —
    // because a fraction short is a fraction overflowed.
    double line(TextStyle style) =>
        scaler.scale(style.fontSize! * (style.height ?? 1)).ceilToDouble();
    final lines =
        line(tokens.typography.styles.heading.heading3) * titleLines +
        line(tokens.typography.styles.body.bodySmall);
    return tokens.spacing.step6 +
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
    final scaler = MediaQuery.textScalerOf(context);
    // Large text (the modal action bar's own threshold): the avatar gives
    // its width to the title, which would otherwise truncate — the
    // handover's own large-text frame drops it too. The status ladder
    // never sheds the name, so nothing is lost but a picture.
    final largeText = scaler.scale(1) > largeTextScale;
    final showsAvatar = !largeText;

    return Container(
      width: double.infinity,
      height: height(tokens, scaler, titleLines: titleLines),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step6,
        tokens.spacing.step5,
        tokens.spacing.step4,
      ),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (showsAvatar) ...[
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
          ],
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
                      maxLines: titleLines,
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
          DesignSystemIconAction(
            key: const ValueKey('check-in-close'),
            icon: LottiIcons.close,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: handle.dismiss,
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

    // At rest the line is a ladder of wordings, widest first, so a narrow
    // phone or large text sheds the date before the person: a check-in is
    // *with* someone, and a bare date under "Log check-in" is a check-in
    // with nobody in it.
    final (Widget? leading, List<String> tiers, Color color) = switch (status) {
      CheckInComposerStatus.idle || CheckInComposerStatus.preparing => (
        null,
        switch ((name, lastSpoke)) {
          (null, _) => const [''],
          (final name?, null) => [
            messages.checkInComposerSubtitleNoContact(name),
            name,
          ],
          (final name?, final at?) => [
            messages.checkInComposerSubtitle(
              name,
              relationshipDayLabelOf(context, at),
            ),
            messages.checkInComposerWithName(name),
            name,
          ],
        },
        quiet,
      ),
      // The red dot alone says "live": error ink on the word would make a
      // take read as a failure, and red on this surface means only that.
      CheckInComposerStatus.recording => (
        _Dot(color: tokens.colors.alert.error.defaultColor),
        [messages.checkInStatusRecording],
        quiet,
      ),
      CheckInComposerStatus.paused => (
        Icon(LottiIcons.pause, size: IconSizes.s, color: quiet),
        [messages.checkInStatusPaused],
        quiet,
      ),
      CheckInComposerStatus.transcribing => (
        DesignSystemSpinner(
          style: DesignSystemSpinnerStyle.plain,
          size: IconSizes.s,
          strokeWidth: tokens.spacing.step1,
        ),
        // The spinner says busy; the word stays in the quiet ink, so accent
        // on text means pressable everywhere.
        [messages.checkInTranscribingLabel],
        quiet,
      ),
      CheckInComposerStatus.transcriptMissing => (
        Icon(
          LottiIcons.warning,
          size: IconSizes.s,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        [messages.checkInStatusTranscriptMissing],
        tokens.colors.alert.warning.ink,
      ),
      CheckInComposerStatus.transcriptionUnavailable => (
        Icon(
          LottiIcons.warning,
          size: IconSizes.s,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        [messages.checkInStatusTranscriptionUnavailable],
        tokens.colors.alert.warning.ink,
      ),
      CheckInComposerStatus.microphoneDenied => (
        Icon(
          LottiIcons.micIdle,
          size: IconSizes.s,
          color: tokens.colors.alert.error.defaultColor,
        ),
        [messages.checkInStatusMicrophoneDenied],
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.recordingFailed => (
        Icon(
          LottiIcons.micIdle,
          size: IconSizes.s,
          color: tokens.colors.alert.error.defaultColor,
        ),
        [messages.checkInStatusRecordingFailed],
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.recordingNotSaved => (
        Icon(
          LottiIcons.micIdle,
          size: IconSizes.s,
          color: tokens.colors.alert.error.defaultColor,
        ),
        [messages.checkInStatusRecordingNotSaved],
        tokens.colors.alert.error.ink,
      ),
      CheckInComposerStatus.recorderBusy => (
        Icon(
          LottiIcons.mic,
          size: IconSizes.s,
          color: tokens.colors.alert.warning.defaultColor,
        ),
        [messages.checkInStatusRecorderBusy],
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
            child: DsTieredText(
              textKey: const ValueKey('check-in-composer-status'),
              tiers: tiers,
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
