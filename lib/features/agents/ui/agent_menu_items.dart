import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// One row of a page's overflow menu on a surface an agent serves — a goal,
/// a person.
///
/// The goal page and the person page each grew their own menu: different row
/// styles, different words for the same entry (*Open agent internals* on one,
/// *Agent internals* on the other), a different order. Built from these, the
/// two read as one menu: the page's own actions first, then the agent's, the
/// internals last among them, and delete always at the bottom in the error
/// ink.
PopupMenuItem<T> agentMenuItem<T>({
  required BuildContext context,
  required T value,
  required IconData icon,
  required String label,
  bool destructive = false,
  Key? key,
}) {
  final tokens = context.designTokens;
  final ink = destructive
      ? tokens.colors.alert.error.ink
      : tokens.colors.text.highEmphasis;
  return PopupMenuItem<T>(
    key: key,
    value: value,
    child: Row(
      children: [
        Icon(icon, color: ink),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: ink,
            ),
          ),
        ),
      ],
    ),
  );
}

/// A setting the menu switches in place — the agent's automatic updates.
///
/// Material's checked menu item lays its row out on a list tile, with its own
/// indent and a bolder label, so it stood out of a menu built from
/// [agentMenuItem]. This keeps the same icon slot (a checkbox showing the
/// state either way) and the same text, and announces the state.
PopupMenuItem<T> agentToggleMenuItem<T>({
  required BuildContext context,
  required T value,
  required String label,
  required bool checked,
  Key? key,
}) {
  final tokens = context.designTokens;
  final ink = tokens.colors.text.highEmphasis;
  return PopupMenuItem<T>(
    key: key,
    value: value,
    child: Semantics(
      checked: checked,
      child: Row(
        children: [
          Icon(
            checked ? LottiIcons.checkboxChecked : LottiIcons.checkboxUnchecked,
            color: ink,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The menu's way into the agent's internals — the same words and glyph on
/// every page that offers it, and the title of the panel it opens.
PopupMenuItem<T> agentInternalsMenuItem<T>({
  required BuildContext context,
  required T value,
  Key? key,
}) => agentMenuItem(
  context: context,
  value: value,
  icon: LottiIcons.tune,
  label: context.messages.aiInternalsTitle,
  key: key,
);
