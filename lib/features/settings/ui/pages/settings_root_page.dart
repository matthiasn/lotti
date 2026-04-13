import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/settings/ui/pages/settings_content_pane.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// Root page for the settings tab. On desktop (>= 960 px) it renders a
/// two-pane layout: the settings menu list on the left and the selected
/// content page on the right, matching the pattern used by tasks and
/// projects. On mobile it simply shows [SettingsPage].
class SettingsRootPage extends ConsumerWidget {
  const SettingsRootPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopLayout(context)) {
      return const SettingsPage();
    }

    final paneWidths = ref.watch(paneWidthControllerProvider);

    return Row(
      children: [
        SizedBox(
          width: paneWidths.listPaneWidth,
          child: const SettingsPage(),
        ),
        ResizableDivider(
          onDrag: (delta) => ref
              .read(paneWidthControllerProvider.notifier)
              .updateListPaneWidth(delta),
        ),
        Expanded(
          child: ValueListenableBuilder<DesktopSettingsRoute?>(
            valueListenable: getIt<NavService>().desktopSelectedSettingsRoute,
            builder: (context, settingsRoute, _) {
              if (settingsRoute == null || settingsRoute.path == '/settings') {
                return DesktopDetailEmptyState(
                  message: context.messages.desktopEmptyStateSelectSetting,
                  icon: Icons.settings_outlined,
                );
              }
              return SettingsContentPane(
                key: ValueKey(settingsRoute.path),
                route: settingsRoute,
              );
            },
          ),
        ),
      ],
    );
  }
}
