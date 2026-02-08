import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

class CollapsibleSection extends StatefulWidget {
  const CollapsibleSection({
    required this.header,
    required this.child,
    super.key,
  });

  final Widget header;
  final Widget child;

  @override
  State<CollapsibleSection> createState() => CollapsibleSectionState();
}

@visibleForTesting
class CollapsibleSectionState extends State<CollapsibleSection> {
  bool isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final color = context.colorScheme.outline;

    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => isExpanded = !isExpanded),
          child: Column(
            children: [
              AnimatedRotation(
                turns: isExpanded ? 0.0 : -0.25,
                duration: AppTheme.chevronRotationDuration,
                child: Icon(
                  Icons.expand_more,
                  size: AppTheme.chevronSize,
                  color: color,
                ),
              ),
              widget.header,
            ],
          ),
        ),
        AnimatedSize(
          duration: AppTheme.collapseAnimationDuration,
          curve: Curves.easeOutCubic,
          child: isExpanded ? widget.child : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
