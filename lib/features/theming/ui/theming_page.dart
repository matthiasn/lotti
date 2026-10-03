import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:material_ui/material_ui.dart';

/// Mobile / legacy wrapper. Keeps the existing `SliverBoxAdapterPage`
/// chrome and delegates content to [ThemingBody] so the same widget
/// can render inside the Settings V2 detail pane (plan step 7).
class ThemingPage extends StatelessWidget {
  const ThemingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsThemingTitle,
      showBackButton: true,
      child: const ThemingBody(),
    );
  }
}

/// Content body for the theming page: the light/dark/system mode toggle.
///
/// There is exactly one theme — the design system's — so mode selection is
/// the only preference left. Extracted from [ThemingPage] so the V2 detail
/// pane can host it without the sliver chrome.
class ThemingBody extends ConsumerWidget {
  const ThemingBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final controller = ref.read(themingControllerProvider.notifier);

    if (themingState.darkTheme == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ModernBaseCard(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: DsSegmentedToggle<ThemeMode>(
              selected: themingState.themeMode,
              onChanged: (mode) => controller.onThemeSelectionChanged({mode}),
              segments: [
                DsSegment(
                  ThemeMode.dark,
                  context.messages.settingsThemingDark,
                  icon: LottiIcons.night,
                  activeIcon: LottiIconsFilled.moon,
                ),
                DsSegment(
                  ThemeMode.system,
                  context.messages.settingsThemingAutomatic,
                  icon: isMobile ? LottiIcons.phone : LottiIcons.laptop,
                  activeIcon: isMobile ? LottiIcons.phone : LottiIcons.laptop,
                ),
                DsSegment(
                  ThemeMode.light,
                  context.messages.settingsThemingLight,
                  icon: LottiIcons.day,
                  activeIcon: LottiIcons.day,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
