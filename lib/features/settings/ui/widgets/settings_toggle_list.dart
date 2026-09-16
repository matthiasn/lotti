import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:material_ui/material_ui.dart';

/// One row of a [SettingsToggleList]: an icon, a title, a wrapping
/// description and the switch that writes the setting.
class SettingsToggleRow {
  const SettingsToggleRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;

  /// Receives the new value, whether the switch was flipped or the row
  /// tapped.
  final ValueChanged<bool> onChanged;

  /// A row that cannot be switched right now — its master setting is off —
  /// renders its toggle disabled and ignores taps on the row.
  final bool enabled;

  /// Identifies the row's list item, for tests and for scrolling to it.
  final Key? key;
}

/// The bordered, rounded card of toggle rows the settings pages share: the
/// config flags and the notification preferences render the same shape.
///
/// A tap anywhere on a row flips it, the same as its switch. The divider
/// under a hovered row fades so the row is never bisected by a hairline.
class SettingsToggleList extends StatefulWidget {
  const SettingsToggleList({required this.rows, super.key});

  final List<SettingsToggleRow> rows;

  @override
  State<SettingsToggleList> createState() => _SettingsToggleListState();
}

class _SettingsToggleListState extends State<SettingsToggleList>
    with HoverDividerIndex<SettingsToggleList> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final rows = widget.rows;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, row) in rows.indexed)
              DesignSystemListItem(
                key: row.key,
                title: row.title,
                subtitle: row.subtitle,
                // `null` lifts the default single-line cap so a long
                // description wraps instead of truncating with an ellipsis.
                subtitleMaxLines: null,
                leading: SettingsIcon(icon: row.icon),
                trailing: DesignSystemToggle(
                  value: row.value,
                  enabled: row.enabled,
                  semanticsLabel: row.title,
                  onChanged: row.onChanged,
                ),
                onTap: row.enabled ? () => row.onChanged(!row.value) : null,
                onHoverChanged: (hovered) =>
                    onRowHoverChanged(index, hovered: hovered),
                // Keep `showDivider` stable so layout doesn't shift by 1 px
                // on hover; fade the divider instead.
                showDivider: index < rows.length - 1,
                dividerColor: hoverDividerColorFor(index),
                dividerIndent: SettingsIcon.dividerIndent(tokens),
              ),
          ],
        ),
      ),
    );
  }
}
