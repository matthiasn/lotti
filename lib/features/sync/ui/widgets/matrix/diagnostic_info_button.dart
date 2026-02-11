import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';

class DiagnosticInfoButton extends ConsumerWidget {
  const DiagnosticInfoButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LottiSecondaryButton(
      label: context.messages.settingsMatrixDiagnosticShowButton,
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
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: prettyJson));
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.messages.settingsMatrixDiagnosticCopied,
                        ),
                      ),
                    );
                  }
                },
                child: Text(context.messages.settingsMatrixDiagnosticCopyButton),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(context.messages.tasksLabelsDialogClose),
              ),
            ],
          ),
        );
      },
    );
  }
}
