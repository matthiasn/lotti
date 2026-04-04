import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

// ── JSON Parsing Helpers ────────────────────────────────────────────────────

/// Reads an integer from a dynamic JSON map, returning [fallback] if the
/// value is missing or not a number.
int readInt(Map<String, Object?> json, String key, [int fallback = 0]) =>
    (json[key] is num) ? (json[key]! as num).toInt() : fallback;

/// Reads a double from a dynamic JSON map, returning [fallback] if the
/// value is missing or not a number.
double readDouble(
  Map<String, Object?> json,
  String key, [
  double fallback = 0.0,
]) => (json[key] is num) ? (json[key]! as num).toDouble() : fallback;

/// Reads an optional num from a dynamic JSON map.
num? readNumOrNull(Map<String, Object?> json, String key) =>
    json[key] is num ? json[key]! as num : null;

/// Reads a string from a dynamic JSON map, returning [fallback] if the
/// value is missing or not a string.
String readString(
  Map<String, Object?> json,
  String key, [
  String fallback = '',
]) => json[key] is String ? json[key]! as String : fallback;

/// Reads an optional string from a dynamic JSON map.
String? readStringOrNull(Map<String, Object?> json, String key) =>
    json[key] is String ? json[key]! as String : null;

/// Reads a list of maps from a dynamic JSON map, filtering out non-map items.
List<Map<String, Object?>> readMapList(
  Map<String, Object?> json,
  String key,
) => (json[key] is List)
    ? (json[key]! as List).whereType<Map<String, Object?>>().toList()
    : <Map<String, Object?>>[];

// ── Shared Widget Helpers ─────────────────────────────────────────────────

/// Renders a section label with a medium label style.
Widget sectionLabel(BuildContext context, String text) {
  return Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );
}

/// Renders a directive box with optional highlight styling.
Widget directiveBox({
  required BuildContext context,
  required String text,
  bool isHighlighted = false,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final tokens = context.designTokens;

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isHighlighted
          ? colorScheme.primaryContainer.withValues(alpha: 0.22)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(tokens.radii.l),
      border: Border.all(
        color: isHighlighted
            ? colorScheme.primary.withValues(alpha: 0.35)
            : colorScheme.outlineVariant.withValues(alpha: 0.35),
      ),
    ),
    child: AgentMarkdownView(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        height: 1.55,
      ),
    ),
  );
}

/// A primary action button used across catalog widgets.
Widget primaryActionButton({
  required String label,
  required VoidCallback onPressed,
}) {
  return DesignSystemButton(
    onPressed: onPressed,
    label: label,
    size: DesignSystemButtonSize.medium,
  );
}

/// A small chip displaying a label and a value.
Widget metricChip(String label, String value) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
        ),
      ),
    ],
  );
}
