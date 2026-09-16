import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_labels.dart';
import 'package:lotti/features/settings/ui/widgets/settings_toggle_list.dart';
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
/// reflects what was stored rather than what was tapped. The card itself is
/// [SettingsToggleList], the shape Settings → Notifications renders too.
class ConfigFlagToggleList extends StatelessWidget {
  const ConfigFlagToggleList({required this.flags, this.labels, super.key});

  /// Rows to render, in display order.
  final List<ConfigFlag> flags;

  /// How a row is titled and described. Defaults to
  /// [ConfigFlagLabels.resolverFor]; Sections passes
  /// [ConfigFlagLabels.sectionResolverFor] so its rows are named after the
  /// navigation destinations they switch on.
  final FlagLabelResolver? labels;

  @override
  Widget build(BuildContext context) {
    final resolve = labels ?? ConfigFlagLabels.resolverFor(context);
    return SettingsToggleList(
      rows: [
        for (final flag in flags)
          // Resolved once per row: the catalog switch would otherwise run for
          // the title and again for the subtitle.
          if (resolve(flag) case (:final title, :final subtitle))
            SettingsToggleRow(
              title: title,
              subtitle: subtitle,
              icon: ConfigFlagLabels.iconFor(flag.name),
              value: flag.status,
              onChanged: (status) => getIt<PersistenceLogic>().setConfigFlag(
                flag.copyWith(status: status),
              ),
            ),
      ],
    );
  }
}
