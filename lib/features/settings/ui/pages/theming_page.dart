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
    return SliverBoxAdapterPage(
      title: context.messages.settingsThemingTitle,
      showBackButton: true,
      child: ModernBaseCard(
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
                semanticsLabel: 'Select light theme',
                getSelected: (state) => state.lightThemeName ?? '',
              ),
              const SizedBox(
                height: 25,
              ),
              SelectTheme(
                setTheme: controller.setDarkTheme,
                labelText: context.messages.settingThemingDark,
                semanticsLabel: 'Select dark theme',
                getSelected: (state) => state.darkThemeName ?? '',
              ),
            ],
          ),
        ),
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
    final controller = TextEditingController()
      ..text = getSelected(themingState);

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
                  ...themes.keys.map(
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

    return TextField(
      onTap: onTap,
      readOnly: true,
      focusNode: FocusNode(),
      controller: controller,
      decoration: inputDecoration(
        labelText: labelText,
        semanticsLabel: semanticsLabel,
        themeData: Theme.of(context),
      ).copyWith(
        border: InputBorder.none,
      ),
    );
  }
}
