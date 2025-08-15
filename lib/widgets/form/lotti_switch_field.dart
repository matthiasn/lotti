import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A reusable switch field widget that follows the Lotti design system
///
/// This widget provides a consistent switch experience across the app
/// with support for titles, subtitles, and icons.
class LottiSwitchField extends StatelessWidget {
  const LottiSwitchField({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.enabled = true,
    this.dense = false,
    this.contentPadding,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final bool enabled;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: enabled
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          subtitle: subtitle != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: enabled
                          ? colorScheme.onSurfaceVariant.withValues(alpha: 0.8)
                          : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                )
              : null,
          value: value,
          onChanged: enabled ? onChanged : null,
          dense: dense,
          contentPadding: contentPadding ??
              const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
          secondary: icon != null
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: enabled
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.5),
                  ),
                )
              : null,
          activeThumbColor: colorScheme.primary,
          inactiveThumbColor: colorScheme.outline,
          inactiveTrackColor: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
