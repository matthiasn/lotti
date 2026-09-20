import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_labels.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:material_ui/material_ui.dart';

/// The bordered, rounded card of config-flag toggle rows.
///
/// Shared by Settings → Sections and Settings → Advanced → Config Flags: both
/// render the same stored [ConfigFlag]s, so both write through the same row —
/// one tap target, one toggle semantics, one hover-divider treatment. Which
/// flags a surface shows is the surface's business; how a flag row looks and
/// what tapping it does is this widget's.
///
/// Rows are labelled through [ConfigFlagLabels], and a tap on either the row
/// or its toggle persists the inverted status via [PersistenceLogic]. There is
/// no local state: the caller rebuilds from `watchConfigFlags()`, so the toggle
/// reflects what was stored rather than what was tapped.
class ConfigFlagToggleList extends StatefulWidget {
  const ConfigFlagToggleList({required this.flags, this.labels, super.key});

  /// Rows to render, in display order.
  final List<ConfigFlag> flags;

  /// How a row is titled and described. Defaults to
  /// [ConfigFlagLabels.resolverFor]; Sections passes
  /// [ConfigFlagLabels.sectionResolverFor] so its rows are named after the
  /// navigation destinations they switch on.
  final FlagLabelResolver? labels;

  @override
  State<ConfigFlagToggleList> createState() => _ConfigFlagToggleListState();
}

class _ConfigFlagToggleListState extends State<ConfigFlagToggleList>
    with HoverDividerIndex<ConfigFlagToggleList> {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final flags = widget.flags;
    final labels = widget.labels ?? ConfigFlagLabels.resolverFor(context);
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
            for (final (index, flag) in flags.indexed)
              _row(tokens, index: index, flag: flag, label: labels(flag)),
          ],
        ),
      ),
    );
  }

  /// One flag row. [label] is resolved by the caller so the catalog switch
  /// runs once per row rather than once per field that reads it — the title
  /// alone is needed twice, visibly and as the toggle's semantics label.
  Widget _row(
    DsTokens tokens, {
    required int index,
    required ConfigFlag flag,
    required ({String title, String subtitle}) label,
  }) {
    return DesignSystemListItem(
      title: label.title,
      subtitle: label.subtitle,
      // `null` lifts the default single-line cap so long descriptions
      // ("Generate AI summary for task actions", etc.) wrap onto a second /
      // third line instead of truncating with ellipsis.
      subtitleMaxLines: null,
      leading: SettingsIcon(icon: ConfigFlagLabels.iconFor(flag.name)),
      trailing: DesignSystemToggle(
        value: flag.status,
        semanticsLabel: label.title,
        onChanged: (bool status) => _setStatus(flag, status),
      ),
      onTap: () => _setStatus(flag, !flag.status),
      onHoverChanged: (hovered) => onRowHoverChanged(index, hovered: hovered),
      // Keep `showDivider` stable so layout doesn't shift by 1 px on hover;
      // fade the divider to transparent when either this row or the row below
      // it is hovered, so the hovered row is never bisected by a hairline.
      showDivider: index < widget.flags.length - 1,
      dividerColor: hoverDividerColorFor(index),
      dividerIndent: SettingsIcon.dividerIndent(tokens),
    );
  }

  void _setStatus(ConfigFlag flag, bool status) {
    getIt<PersistenceLogic>().setConfigFlag(flag.copyWith(status: status));
  }
}
