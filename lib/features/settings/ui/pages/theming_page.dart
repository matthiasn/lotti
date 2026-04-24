import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

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

/// Content body for the theming page. Mode toggle + light/dark theme
/// pickers inside a single card — extracted from [ThemingPage] so
/// the V2 detail pane can host it without the sliver chrome.
class ThemingBody extends ConsumerWidget {
  const ThemingBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final controller = ref.read(themingControllerProvider.notifier);

    ButtonSegment<ThemeMode> segment({
      required ThemeMode filter,
      required IconData icon,
      required IconData activeIcon,
      required String semanticLabel,
    }) {
      final active = themingState.themeMode == filter;
      return ButtonSegment<ThemeMode>(
        value: filter,
        label: Tooltip(
          message: semanticLabel,
          child: Icon(
            active ? activeIcon : icon,
            semanticLabel: semanticLabel,
            color: context.textTheme.titleLarge?.color ?? Colors.grey,
            size: 25,
          ),
        ),
      );
    }

    if (themingState.darkTheme == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        ModernBaseCard(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              children: [
                SegmentedButton<ThemeMode>(
                  selected: {themingState.themeMode},
                  showSelectedIcon: false,
                  onSelectionChanged: controller.onThemeSelectionChanged,
                  segments: [
                    segment(
                      filter: ThemeMode.dark,
                      icon: Icons.nightlight_outlined,
                      activeIcon: Icons.nightlight,
                      semanticLabel: context.messages.settingsThemingDark,
                    ),
                    segment(
                      filter: ThemeMode.system,
                      icon: isMobile ? Icons.smartphone : Icons.laptop,
                      activeIcon: isMobile
                          ? Icons.smartphone_outlined
                          : Icons.laptop_outlined,
                      semanticLabel: context.messages.settingsThemingAutomatic,
                    ),
                    segment(
                      filter: ThemeMode.light,
                      icon: Icons.wb_sunny_outlined,
                      activeIcon: Icons.sunny,
                      semanticLabel: context.messages.settingsThemingLight,
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                SelectTheme(
                  setTheme: controller.setLightTheme,
                  labelText: context.messages.settingThemingLight,
                  semanticsLabel: context.messages.settingThemingLight,
                  getSelected: (state) => state.lightThemeName ?? '',
                ),
                const SizedBox(height: 25),
                SelectTheme(
                  setTheme: controller.setDarkTheme,
                  labelText: context.messages.settingThemingDark,
                  semanticsLabel: context.messages.settingThemingDark,
                  getSelected: (state) => state.darkThemeName ?? '',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class SelectTheme extends ConsumerWidget {
  const SelectTheme({
    required this.setTheme,
    required this.getSelected,
    required this.labelText,
    required this.semanticsLabel,
    super.key,
  });

  final void Function(String) setTheme;
  final String Function(ThemingState) getSelected;
  final String labelText;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themingState = ref.watch(themingControllerProvider);
    final selectedThemeName = getSelected(themingState);
    final themeData = Theme.of(context);

    void onTap() {
      ModalUtils.showBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext _) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...allThemeNames.map(
                    (key) => SettingsCard(
                      onTap: () {
                        setTheme(key);
                        Navigator.pop(context);
                      },
                      title: key,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: inputDecoration(
          labelText: labelText,
          semanticsLabel: semanticsLabel,
          themeData: themeData,
        ).copyWith(border: InputBorder.none),
        child: Text(
          selectedThemeName,
          style: themeData.textTheme.titleMedium,
        ),
      ),
    );
  }
}
