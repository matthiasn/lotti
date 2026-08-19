import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_variant.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/settings/state/celebration_preferences_controller.dart';
import 'package:lotti/features/sync/ui/widgets/sync_device_pair_motif.dart';
import 'package:lotti/features/sync/ui/widgets/sync_well.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:matrix/encryption/utils/key_verification.dart';

/// The shared stages of a SAS (emoji) ceremony, rendered identically whether
/// this device started the verification or is answering one.
///
/// One definition for both modals, on the token grid: hand-spaced copies had
/// drifted into raw `SizedBox` literals, `Opacity` in place of emphasis
/// tokens, `Colors.greenAccent` for success, and a danger-red Cancel on a
/// step where cancelling is a safe, ordinary act.
///
/// Names the counterpart device — the thing being trusted — as a compact
/// identity card: device name with its account and session id in mono,
/// because those are compare-me identifiers, not prose.
class VerificationCeremonyHeader extends StatelessWidget {
  const VerificationCeremonyHeader({
    required this.deviceName,
    this.userId,
    this.deviceId,
    super.key,
  });

  final String deviceName;

  /// The account the device belongs to; omitted where the caller cannot
  /// resolve it.
  final String? userId;

  /// The Matrix session id, appended to the account line when known.
  final String? deviceId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final meta = [?userId, ?deviceId].join(' · ');

    return SyncWell(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step4,
      ),
      child: Row(
        children: [
          Icon(
            LottiIcons.devices,
            size: IconSizes.l,
            color: tokens.colors.text.mediumEmphasis,
          ),
          SizedBox(width: tokens.spacing.step4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deviceName,
                  softWrap: true,
                  style: tokens.typography.styles.subtitle.subtitle2,
                ),
                if (meta.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    meta,
                    style: monoMetaStyle(
                      tokens,
                      tokens.colors,
                      base: tokens.typography.styles.others.caption,
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The emoji comparison: a literal question, the grid as the only saturated
/// thing on screen, and the accept/cancel pair that states what each means.
///
/// Cancel is a quiet tertiary, not danger: backing out of a ceremony is
/// ordinary and reversible, and painting it red taught users the flow's only
/// red button was also its safest.
class VerificationEmojiStage extends StatelessWidget {
  const VerificationEmojiStage({
    required this.emojis,
    required this.awaitingOtherDevice,
    required this.onAccept,
    required this.onCancel,
    super.key,
  });

  final Iterable<KeyVerificationEmoji> emojis;

  /// True once this side confirmed and the ceremony waits on the peer; the
  /// accept button disables and carries the waiting label.
  final bool awaitingOtherDevice;
  final VoidCallback onAccept;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      children: [
        if (awaitingOtherDevice) ...[
          Text(
            messages.settingsMatrixContinueVerificationLabel,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
        // The question, literally: same emoji, same order — the two halves
        // at two ranks so the decision line is the one that lands.
        Text(
          messages.syncVerifyPromptLine1,
          style: tokens.typography.styles.body.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          messages.syncVerifyPromptQuestion,
          style: tokens.typography.styles.subtitle.subtitle1,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step5),
        VerificationEmojiGrid(emojis: emojis),
        SizedBox(height: tokens.spacing.step5),
        LayoutBuilder(
          builder: (context, constraints) {
            final accept = DesignSystemButton(
              onPressed: awaitingOtherDevice ? null : onAccept,
              label: awaitingOtherDevice
                  ? messages.settingsMatrixContinueVerificationLabel
                  : messages.syncVerifyTheyMatch,
              leadingIcon: awaitingOtherDevice ? null : LottiIcons.confirm,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
            );
            final stacked =
                constraints.maxWidth < kVerificationDecisionRowMinWidth;
            final cancel = DesignSystemButton(
              key: const Key('matrix_cancel_verification'),
              onPressed: onCancel,
              label: messages.syncVerifyTheyDiffer,
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.large,
              fullWidth: stacked,
            );
            // Two spelled-out decisions share a phone sheet's width badly;
            // below the wide-card breakpoint they stack, accent on top.
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  accept,
                  SizedBox(height: tokens.spacing.step3),
                  cancel,
                ],
              );
            }
            return DesignSystemModalActionBar(
              secondary: [cancel],
              primary: accept,
            );
          },
        ),
      ],
    );
  }
}

/// Below this width the emoji stage stacks its decision pair: "They match"
/// and "They differ — cancel" are deliberately spelled-out labels, and side
/// by side they truncate on a phone sheet.
const double kVerificationDecisionRowMinWidth = 420;

/// The SAS emoji as a four-column grid of glyph-plus-label cells, each on
/// its own level-01 well so the sequence reads as discrete things to
/// compare rather than one decorative strip.
class VerificationEmojiGrid extends StatelessWidget {
  const VerificationEmojiGrid({required this.emojis, super.key});

  final Iterable<KeyVerificationEmoji> emojis;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.step3;

    // A wrap of fixed-width, intrinsic-height cells rather than a GridView:
    // an aspect-ratio grid clips the glyph-plus-label stack on narrow sheets
    // and at large text scales, where a cell that sizes to its content
    // simply grows.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = (constraints.maxWidth - 3 * gap) / 4;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final emoji in emojis)
              SizedBox(
                width: cellWidth,
                child: SyncWell(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.step3,
                    horizontal: tokens.spacing.step1,
                  ),
                  child: Column(
                    children: [
                      Text(
                        emoji.emoji,
                        style: tokens.typography.styles.heading.heading2,
                      ),
                      SizedBox(height: tokens.spacing.step1),
                      // Free to wrap: the word is the textual disambiguation
                      // this security comparison relies on, and an ellipsized
                      // label defeats exactly that. Cells grow with content.
                      Text(
                        emoji.name,
                        textAlign: TextAlign.center,
                        style: tokens.typography.styles.others.caption.copyWith(
                          color: tokens.colors.text.mediumEmphasis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The terminal success stage — the one place in the journey the celebration
/// system fires. The two-device motif closes into a solid line, brand sparks
/// burst once, and the copy states the property that was just established.
class VerificationSuccessStage extends ConsumerStatefulWidget {
  const VerificationSuccessStage({
    required this.onConfirm,
    super.key,
  });

  final VoidCallback onConfirm;

  @override
  ConsumerState<VerificationSuccessStage> createState() =>
      _VerificationSuccessStageState();
}

class _VerificationSuccessStageState
    extends ConsumerState<VerificationSuccessStage> {
  bool _celebrated = false;

  @override
  void initState() {
    super.initState();
    // Fire-and-forget into the app overlay; a no-op under reduced motion —
    // and gated by the app's own celebration master switch, with the user's
    // customized spark parameters.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _celebrated) return;
      _celebrated = true;
      final prefs = ref.read(celebrationPreferencesProvider);
      if (!prefs.enabled) return;
      spawnCompletionBurst(
        context,
        params: prefs.paramsFor(CelebrationVariant.sparks),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      key: const Key('verification_success_stage'),
      children: [
        SizedBox(height: tokens.spacing.step4),
        const SyncDevicePairMotif(state: SyncDevicePairMotifState.linked),
        SizedBox(height: tokens.spacing.step5),
        Text(
          messages.syncVerifiedCelebrationTitle,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.syncVerifiedCelebrationBody,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DesignSystemButton(
              onPressed: widget.onConfirm,
              label: context.messages.settingsMatrixVerificationSuccessConfirm,
              size: DesignSystemButtonSize.large,
            ),
          ],
        ),
      ],
    );
  }
}

/// The terminal cancelled stage: the notice and the one way out.
class VerificationCancelledStage extends StatelessWidget {
  const VerificationCancelledStage({
    required this.onConfirm,
    super.key,
    this.confirmKey,
  });

  final VoidCallback onConfirm;
  final Key? confirmKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      children: [
        Text(
          context.messages.settingsMatrixVerificationCancelledLabel,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodyMedium,
        ),
        SizedBox(height: tokens.spacing.step5),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DesignSystemButton(
              key: confirmKey,
              onPressed: onConfirm,
              label: context.messages.settingsMatrixVerificationSuccessConfirm,
              size: DesignSystemButtonSize.large,
            ),
          ],
        ),
      ],
    );
  }
}
