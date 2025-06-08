import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A styled switch field component that matches the AI Settings design language
class AiSwitchField extends StatelessWidget {
  const AiSwitchField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
    this.enabled = true,
    this.icon,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? description;
  final bool enabled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.surfaceContainer.withValues(alpha: 0.3),
            context.colorScheme.surfaceContainerHigh.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? context.colorScheme.primary.withValues(alpha: 0.3)
              : context.colorScheme.primaryContainer.withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
          borderRadius: BorderRadius.circular(12),
          splashColor: context.colorScheme.primary.withValues(alpha: 0.1),
          highlightColor: context.colorScheme.primary.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: value
                          ? context.colorScheme.primaryContainer
                              .withValues(alpha: 0.3)
                          : context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 18,
                      color: value
                          ? context.colorScheme.primary
                          : context.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? context.colorScheme.onSurface
                              : context.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                          letterSpacing: 0.3,
                        ),
                      ),
                      if (description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          description!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: context.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  activeTrackColor: context.colorScheme.primary,
                  activeColor: context.colorScheme.onPrimary,
                  inactiveThumbColor: context.colorScheme.onSurfaceVariant,
                  inactiveTrackColor:
                      context.colorScheme.surfaceContainerHighest,
                  trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return context.colorScheme.primary.withValues(alpha: 0.3);
                    }
                    return context.colorScheme.primaryContainer
                        .withValues(alpha: 0.3);
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
