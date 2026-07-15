import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/ui/command_catalog_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';

/// Opens the searchable, keyboard-navigable command palette.
Future<void> showAppCommandPalette(
  BuildContext context,
  AppCommandContextSnapshot snapshot,
) async {
  final invokingFocus = FocusManager.instance.primaryFocus;
  final selectedCommand = await showDialog<AppCommandId>(
    context: context,
    builder: (dialogContext) => _CommandPaletteDialog(snapshot: snapshot),
  );
  if (invokingFocus?.context?.mounted ?? false) {
    invokingFocus?.requestFocus();
  }
  if (selectedCommand != null) {
    await snapshot.invoke(selectedCommand);
  }
}

class _CommandPaletteDialog extends StatelessWidget {
  const _CommandPaletteDialog({required this.snapshot});

  final AppCommandContextSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final availableHeight =
        MediaQuery.sizeOf(context).height - (tokens.spacing.step13 * 2);
    return Dialog(
      insetPadding: EdgeInsets.all(tokens.spacing.step6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: WoltModalConfig.pageBreakpoint.toDouble(),
          maxHeight: availableHeight,
        ),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.messages.commandPaletteTitle,
                style: tokens.typography.styles.heading.heading3.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step5),
              Expanded(
                child: CommandCatalogView(
                  paletteMode: true,
                  snapshot: snapshot,
                  onCommandSelected: (id) => Navigator.of(context).pop(id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
