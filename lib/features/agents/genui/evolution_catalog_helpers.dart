import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/agent_palette.dart';
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

// ── Feedback widget helpers ─────────────────────────────────────────────────────────

Widget sentimentChip(String label, int count, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(
      '$count $label',
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}

Widget feedbackLine({required String detail, required String sentiment}) {
  final color = switch (sentiment) {
    'negative' => AgentPalette.red,
    'positive' => AgentPalette.green,
    _ => AgentPalette.orange,
  };

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 16,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget highPrioritySectionHeader(String label, int count, Color color) {
  return Row(
    children: [
      Container(
        width: 4,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        '$label ($count)',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

Widget highPriorityItemTile({
  required String agentId,
  required String detail,
  required Color accentColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 16,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        if (agentId.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              '[$agentId]',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            detail,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget categoryBar({
  required String name,
  required int count,
  required int positiveCount,
  required int negativeCount,
  required int totalCount,
}) {
  final fraction = totalCount > 0 ? count / totalCount : 0.0;
  final neutralCount = max(0, count - positiveCount - negativeCount);

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 6,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Row(
                children: [
                  if (negativeCount > 0)
                    Expanded(
                      flex: negativeCount,
                      child: Container(color: AgentPalette.red),
                    ),
                  if (positiveCount > 0)
                    Expanded(
                      flex: positiveCount,
                      child: Container(color: AgentPalette.green),
                    ),
                  if (neutralCount > 0)
                    Expanded(
                      flex: neutralCount,
                      child: Container(color: AgentPalette.orange),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
