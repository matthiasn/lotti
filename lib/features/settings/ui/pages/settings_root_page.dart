import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings_v2/ui/pages/settings_v2_page.dart';

/// Root page for the Settings tab.
///
/// On mobile (< 960 px) it falls back to the single-page [SettingsPage]
/// with push navigation. On desktop it renders the tree-nav layout via
/// [SettingsV2Page].
class SettingsRootPage extends StatelessWidget {
  const SettingsRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) {
      return const SettingsPage();
    }
    return const SettingsV2Page();
  }
}
