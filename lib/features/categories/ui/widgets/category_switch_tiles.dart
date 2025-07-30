import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// Data class for category switch settings
class CategorySwitchSettings {
  const CategorySwitchSettings({
    required this.isPrivate,
    required this.isActive,
    required this.isFavorite,
  });

  final bool isPrivate;
  final bool isActive;
  final bool isFavorite;
}

/// Callback type for switch value changes
typedef SwitchFieldChanged = void Function(SwitchFieldType field,
    {required bool value});

/// Enum to identify which switch was changed
enum SwitchFieldType { private, active, favorite }

/// A widget that displays three switch tiles for category settings.
///
/// This widget shows switches for private, active, and favorite settings.
/// It's designed to be independent of Riverpod for better testability.
class CategorySwitchTiles extends StatelessWidget {
  const CategorySwitchTiles({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final CategorySwitchSettings settings;
  final SwitchFieldChanged onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LottiSwitchField(
          title: context.messages.privateLabel,
          subtitle: context.messages.categoryPrivateDescription,
          value: settings.isPrivate,
          onChanged: (value) =>
              onChanged(SwitchFieldType.private, value: value),
          icon: Icons.lock_outline,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.activeLabel,
          subtitle: context.messages.categoryActiveDescription,
          value: settings.isActive,
          onChanged: (value) => onChanged(SwitchFieldType.active, value: value),
          icon: Icons.visibility_outlined,
        ),
        const SizedBox(height: 8),
        LottiSwitchField(
          title: context.messages.favoriteLabel,
          subtitle: context.messages.categoryFavoriteDescription,
          value: settings.isFavorite,
          onChanged: (value) =>
              onChanged(SwitchFieldType.favorite, value: value),
          icon: Icons.star_outline,
        ),
      ],
    );
  }
}
