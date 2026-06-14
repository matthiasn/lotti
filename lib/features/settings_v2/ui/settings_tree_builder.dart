import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';

/// Builds the flag-gated, localized settings tree from the current
/// Riverpod config-flag state.
///
/// This is the single source the desktop tree view, the desktop detail
/// pane, the `SettingsTreeScopeHost`, and the mobile drill-down all build
/// from, so the menu structure can never drift between surfaces — add a
/// node once in [buildSettingsTree] and it appears, correctly gated, on
/// every platform.
List<SettingsNode> watchSettingsTree(BuildContext context, WidgetRef ref) {
  return buildSettingsTree(
    labels: settingsTreeLabelsFor(context),
    enableHabits:
        ref.watch(configFlagProvider(enableHabitsPageFlag)).value ?? false,
    enableDashboards:
        ref.watch(configFlagProvider(enableDashboardsPageFlag)).value ?? false,
    enableMatrix:
        ref.watch(configFlagProvider(enableMatrixFlag)).value ?? false,
    enableWhatsNew:
        ref.watch(configFlagProvider(enableWhatsNewFlag)).value ?? false,
    // Health import is an iOS/Android-only utility; it surfaces under the
    // mobile Advanced hub and is absent on desktop platforms (matching the
    // pre-unification behaviour, where the entry was `if (isMobile)`).
    enableHealthImport: isMobile,
  );
}
