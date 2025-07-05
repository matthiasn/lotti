import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

/// A clean section container for filter groups
class CleanFilterSection extends StatelessWidget {
  const CleanFilterSection({
    required this.title,
    required this.children,
    this.subtitle,
    this.useGrid = false,
    this.crossAxisCount = 2,
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool useGrid;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (useGrid)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 8) / crossAxisCount;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: children.map((child) => 
                      SizedBox(
                        width: itemWidth,
                        child: child,
                      ),
                    ).toList(),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}
