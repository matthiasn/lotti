import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/command_catalog_view.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';

/// Persistent Settings destination documenting every desktop shortcut.
class KeyboardShortcutsPage extends StatelessWidget {
  const KeyboardShortcutsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SettingsPageHeader(
            title: context.messages.keyboardShortcutsTitle,
            showBackButton: true,
          ),
          const SliverFillRemaining(child: KeyboardShortcutsBody()),
        ],
      ),
    );
  }
}

/// Headerless shortcut help body used by Settings V2.
class KeyboardShortcutsBody extends StatelessWidget {
  const KeyboardShortcutsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.messages.keyboardShortcutsSubtitle,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          const Expanded(child: CommandCatalogView(paletteMode: false)),
        ],
      ),
    );
  }
}

/// Quick-reference overlay opened by F1 or Primary+?.
Future<void> showKeyboardShortcutsOverlay(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final tokens = dialogContext.designTokens;
      final availableHeight =
          MediaQuery.sizeOf(dialogContext).height - (tokens.spacing.step13 * 2);
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dialogContext.messages.keyboardShortcutsTitle,
                        style: tokens.typography.styles.heading.heading3
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                            ),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        dialogContext,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.step4),
                const Expanded(
                  child: CommandCatalogView(paletteMode: false),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
