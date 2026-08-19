import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

class DiagnosticInfoButton extends ConsumerWidget {
  const DiagnosticInfoButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DesignSystemButton(
      label: context.messages.settingsMatrixDiagnosticShowButton,
      // A support affordance, not a peer of the page's real actions. Neutral
      // rather than tertiary: on the accent it was the only interactive-teal
      // item on a page whose actual primary wore no accent at all.
      // Not alignsLabelToLeadingEdge: this variant draws a border, and the
      // flag pulls the *label* to the rail, hanging the border outside it.
      // Small — the component's default, and deliberately smaller than the
      // account action beside it: a diagnostics dump is the least likely
      // reason anyone opens this sheet.
      variant: DesignSystemButtonVariant.outlined,
      onPressed: () async {
        final info = await ref.read(matrixServiceProvider).getDiagnosticInfo();
        final prettyJson = const JsonEncoder.withIndent('  ').convert(info);

        if (!context.mounted) return;

        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(context.messages.settingsMatrixDiagnosticDialogTitle),
            content: SingleChildScrollView(
              child: SelectableText(
                prettyJson,
                style: monoMetaStyle(
                  context.designTokens,
                  context.designTokens.colors,
                  base: context.designTokens.typography.styles.body.bodySmall,
                  color: context.designTokens.colors.text.highEmphasis,
                ),
              ),
            ),
            actions: [
              DesignSystemButton(
                label: context.messages.settingsMatrixDiagnosticCopyButton,
                variant: DesignSystemButtonVariant.secondary,
                leadingIcon: LottiIcons.copy,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: prettyJson));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    context.showToast(
                      tone: DesignSystemToastTone.success,
                      title: context.messages.settingsMatrixDiagnosticCopied,
                    );
                  }
                },
              ),
              DesignSystemButton(
                label: context.messages.tasksLabelsDialogClose,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        );
      },
    );
  }
}
