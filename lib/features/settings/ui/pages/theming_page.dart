import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/features/theming/model/theme_definitions.dart';
import 'package:lotti/features/theming/state/theming_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/gamey_theme.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/gamey/gamey_card.dart';

class ThemingPage extends ConsumerWidget {
  const ThemingPage({super.key});

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

    final brightness = Theme.of(context).brightness;
    final useGamey = themingState.isGameyThemeForBrightness(brightness);

    // Build the content that goes inside the card
    Widget buildCardContent() {
      return Padding(
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
      );
    }

    return SliverBoxAdapterPage(
      title: context.messages.settingsThemingTitle,
      showBackButton: true,
      child: Column(
        children: [
          // Theme Mode and Color Selection
          if (useGamey)
            GameySubtleCard(
              accentColor: GameyColors.gameyAccent,
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLarge,
                vertical: AppTheme.cardSpacing / 2,
              ),
              padding: EdgeInsets.zero,
              child: buildCardContent(),
            )
          else
            ModernBaseCard(
              margin: const EdgeInsets.all(10),
              child: buildCardContent(),
            ),
        ],
      ),
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
    final isGamey = isGameyTheme(selectedThemeName);
    final colorScheme = Theme.of(context).colorScheme;
    final themeData = Theme.of(context);

    void onTap() {
      showModalBottomSheet<void>(
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
                      trailing: isGameyTheme(key)
                          ? Icon(
                              Icons.auto_awesome,
                              color: colorScheme.primary,
                              size: 20,
                            )
                          : null,
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
        ).copyWith(
          border: InputBorder.none,
          suffixIcon: isGamey
              ? Icon(
                  Icons.auto_awesome,
                  color: colorScheme.primary,
                )
              : null,
        ),
        child: Text(
          selectedThemeName,
          style: themeData.textTheme.titleMedium,
        ),
      ),
    );
  }
}
