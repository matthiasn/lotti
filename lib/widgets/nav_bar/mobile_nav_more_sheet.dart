import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// One overflow destination row in the More sheet.
class MobileNavMoreSheetItem {
  const MobileNavMoreSheetItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.trailing,
    this.active = false,
  });

  final String label;
  final Widget icon;
  final bool active;

  /// Optional widget rendered between the label and the chevron — the
  /// same trailing slot the desktop sidebar rows offer (e.g. the Settings
  /// outbox count pill).
  final Widget? trailing;

  /// Invoked after the sheet is dismissed; navigates to the destination.
  final VoidCallback onSelected;
}

/// Opens the More overflow sheet: every enabled destination that did not fit
/// the five-slot bar, one row each. Selecting a row dismisses the sheet and
/// navigates; the bar's More slot then renders that destination as active.
///
/// The sheet closes with the [ContactSupportRow] footer. Mobile has no
/// persistent chrome to pin it to the way the desktop sidebar does, and this
/// sheet is already where everything that did not fit the bar lives — so it is
/// the one place a phone user reliably passes on the way out of the app's
/// navigation. Those external destinations are *not* destinations — nothing
/// there switches tabs — and what separates them from the rows above is the
/// footer's own spacing and its glyph-only treatment, not a rule.
Future<void> showMobileNavMoreSheet({
  required BuildContext context,
  required List<MobileNavMoreSheetItem> items,
}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.navTabTitleMore,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in items)
          _MoreSheetRow(
            item: item,
            onTap: () {
              Navigator.of(sheetContext).pop();
              item.onSelected();
            },
          ),
        const ContactSupportRow(),
      ],
    ),
  );
}

class _MoreSheetRow extends StatelessWidget {
  const _MoreSheetRow({required this.item, required this.onTap});

  final MobileNavMoreSheetItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tint = item.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.highEmphasis;

    return Semantics(
      button: true,
      selected: item.active,
      label: item.label,
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: DesignSystemFiveSlotNavBar.minTapTarget,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step3,
                vertical: tokens.spacing.step5,
              ),
              child: Row(
                children: [
                  IconTheme.merge(
                    data: IconThemeData(
                      size: DesignSystemFiveSlotNavBar.iconSize,
                      color: item.active
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.mediumEmphasis,
                    ),
                    child: item.icon,
                  ),
                  SizedBox(width: tokens.spacing.step4),
                  Expanded(
                    child: Text(
                      item.label,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tint,
                      ),
                    ),
                  ),
                  if (item.trailing != null) ...[
                    item.trailing!,
                    SizedBox(width: tokens.spacing.step3),
                  ],
                  Icon(
                    LottiIcons.chevronRight,
                    size: DesignSystemFiveSlotNavBar.iconSize,
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
