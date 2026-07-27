import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/widgets/matrix/verification_emojis_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:matrix/encryption/utils/key_verification.dart';

/// The shared stages of a SAS (emoji) ceremony, rendered identically whether
/// this device started the verification or is answering one.
///
/// One definition for both modals, on the token grid: hand-spaced copies had
/// drifted into raw `SizedBox` literals, `Opacity` in place of emphasis
/// tokens, `Colors.greenAccent` for success, and a danger-red Cancel on a
/// step where cancelling is a safe, ordinary act.
class VerificationCeremonyHeader extends StatelessWidget {
  const VerificationCeremonyHeader({
    required this.deviceName,
    this.userId,
    super.key,
  });

  final String deviceName;

  /// The account the device belongs to; omitted where the caller cannot
  /// resolve it.
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final userId = this.userId;

    return Column(
      children: [
        Text(
          deviceName,
          textAlign: TextAlign.center,
          softWrap: true,
          style: tokens.typography.styles.subtitle.subtitle1,
        ),
        if (userId != null) ...[
          SizedBox(height: tokens.spacing.step2),
          Text(
            userId,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The emoji comparison: the prompt, the two rows, and the accept/cancel pair.
///
/// Cancel is a quiet tertiary, not danger: backing out of a ceremony is
/// ordinary and reversible, and painting it red taught users the flow's only
/// red button was also its safest.
class VerificationEmojiStage extends StatelessWidget {
  const VerificationEmojiStage({
    required this.prompt,
    required this.emojis,
    required this.awaitingOtherDevice,
    required this.onAccept,
    required this.onCancel,
    super.key,
  });

  final String prompt;
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
        Text(
          prompt,
          style: tokens.typography.styles.body.bodyMedium,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step5),
        VerificationEmojisRow(emojis.take(4)),
        VerificationEmojisRow(emojis.skip(4)),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemModalActionBar(
          secondary: [
            DesignSystemButton(
              key: const Key('matrix_cancel_verification'),
              onPressed: onCancel,
              label: messages.settingsMatrixCancel,
              variant: DesignSystemButtonVariant.tertiary,
              size: DesignSystemButtonSize.large,
            ),
          ],
          primary: DesignSystemButton(
            onPressed: awaitingOtherDevice ? null : onAccept,
            label: awaitingOtherDevice
                ? messages.settingsMatrixContinueVerificationLabel
                : messages.settingsMatrixAccept,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
          ),
        ),
      ],
    );
  }
}

/// The terminal success stage: message, shield in the success token, confirm.
class VerificationSuccessStage extends StatelessWidget {
  const VerificationSuccessStage({
    required this.message,
    required this.onConfirm,
    super.key,
  });

  final String message;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodyMedium,
        ),
        SizedBox(height: tokens.spacing.step5),
        Icon(
          MdiIcons.shieldCheck,
          color: tokens.colors.alert.success.defaultColor,
          size: tokens.spacing.step12,
        ),
        SizedBox(height: tokens.spacing.step5),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            DesignSystemButton(
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
