import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/misc/contact_support_row.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// One destination in the mobile navigation grid.
class MobileNavSheetItem {
  const MobileNavSheetItem({
    required this.label,
    required this.icon,
    required this.onSelected,
    this.active = false,
  });

  final String label;
  final Widget icon;
  final bool active;

  /// Invoked after the sheet is dismissed; navigates to the destination.
  final VoidCallback onSelected;
}

/// Opens all enabled destinations in a two-column grid, in reading order.
/// Rows grow with their content and the shared modal scrolls on short screens.
/// Selection dismisses the sheet before navigating. Support links remain below
/// the grid on the left, with optional status on the right.
Future<void> showMobileNavSheet({
  required BuildContext context,
  required List<MobileNavSheetItem> items,
  Widget? footerTrailing,
}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.navTabTitleNavigate,
    builder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i += 2)
          Padding(
            padding: EdgeInsets.only(
              bottom: context.designTokens.spacing.step3,
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < 2; column++) ...[
                    if (column > 0)
                      SizedBox(width: context.designTokens.spacing.step3),
                    Expanded(
                      child: i + column < items.length
                          ? _DestinationTile(
                              item: items[i + column],
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                items[i + column].onSelected();
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        Row(
          children: [
            const ContactSupportRow(),
            SizedBox(width: context.designTokens.spacing.step3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: context.designTokens.spacing.step2,
                  right: context.designTokens.spacing.step3,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: footerTrailing ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DestinationTile extends StatelessWidget {
  const _DestinationTile({required this.item, required this.onTap});

  final MobileNavSheetItem item;
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
        color: item.active
            ? tokens.colors.surface.selected
            : tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: InkWell(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: TapTargets.minimum,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  IconTheme.merge(
                    data: IconThemeData(
                      size: IconSizes.m,
                      color: item.active
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.mediumEmphasis,
                    ),
                    child: item.icon,
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  Expanded(
                    child: Text(
                      item.label,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tint,
                      ),
                    ),
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
