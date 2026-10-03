import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/settings/ui/mobile/settings_mobile_root_page.dart';
import 'package:lotti/features/settings/ui/pages/settings_desktop_page.dart';
import 'package:material_ui/material_ui.dart';

/// Root page for the Settings tab.
///
/// On mobile (< 960 px) it renders the unified drill-down landing
/// ([SettingsMobileRootPage]); on desktop it renders the tree-nav
/// master/detail layout ([SettingsDesktopPage]). Both are built from the same
/// `buildSettingsTree` data, so the two surfaces can never disagree about
/// which settings exist or how they are grouped.
class SettingsRootPage extends StatelessWidget {
  const SettingsRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) {
      return const SettingsMobileRootPage();
    }
    return const SettingsDesktopPage();
  }
}
