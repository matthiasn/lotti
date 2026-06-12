import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_five_slot_nav_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
                vertical: tokens.spacing.step3,
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
                    Icons.chevron_right_rounded,
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
