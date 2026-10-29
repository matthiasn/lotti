import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_handler.dart';
import 'package:lotti/features/keyboard/domain/palette_jump.dart';
import 'package:lotti/features/keyboard/ui/command_catalog_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the searchable, keyboard-navigable command palette.
///
/// With [jumpSearch], it also finds tasks, entries, projects, events and
/// people by title, and a chosen one is handed to [onJump] once the palette
/// has closed and focus is back where it was — the way a chosen command is
/// invoked.
Future<void> showAppCommandPalette(
  BuildContext context,
  AppCommandContextSnapshot snapshot, {
  PaletteJumpSearch? jumpSearch,
  ValueChanged<PaletteJumpTarget>? onJump,
}) async {
  final invokingFocus = FocusManager.instance.primaryFocus;
  final selected = await showDialog<Object>(
    context: context,
    builder: (dialogContext) =>
        _CommandPaletteDialog(snapshot: snapshot, jumpSearch: jumpSearch),
  );
  if (invokingFocus?.context?.mounted ?? false) {
    invokingFocus?.requestFocus();
    await Future<void>.value();
  }
  switch (selected) {
    case final AppCommandId command:
      await snapshot.invoke(command);
    case final PaletteJumpTarget target:
      onJump?.call(target);
  }
}

class _CommandPaletteDialog extends StatelessWidget {
  const _CommandPaletteDialog({required this.snapshot, this.jumpSearch});

  final AppCommandContextSnapshot snapshot;
  final PaletteJumpSearch? jumpSearch;

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
                  jumpSearch: jumpSearch,
                  onJumpSelected: (target) => Navigator.of(context).pop(target),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
