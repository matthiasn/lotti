import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/ui/widgets/zigzag_fold_indicator.dart';
import 'package:lotti/features/daily_os/util/timeline_folding_utils.dart';
import 'package:lotti/themes/theme.dart';

/// Width of the zigzag indicator on the left edge.
const double kZigzagIndicatorWidth = 10;

/// A widget that displays a compressed (folded) time region in the timeline.
///
/// When tapped, it signals to expand the region to full height.
/// The widget shows:
/// - A zigzag pattern on the left edge indicating compression
/// - Faint hour lines at compressed scale
/// - A label showing the time range
class CompressedTimelineRegion extends StatelessWidget {
  const CompressedTimelineRegion({
    required this.region,
    required this.onTap,
    required this.timeAxisWidth,
    super.key,
  });

  /// The compressed region to display.
  final CompressedRegion region;

  /// Callback when the region is tapped to expand.
  final VoidCallback onTap;

  /// Width of the time axis on the left side.
  final double timeAxisWidth;

  @override
  Widget build(BuildContext context) {
    final totalHeight = region.hourCount * kCompressedHourHeight;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        label: 'Compressed time region from ${region.startHour}:00 to '
            '${region.endHour}:00. Tap to expand.',
        button: true,
        child: SizedBox(
          height: totalHeight,
          child: Row(
            children: [
              // Time axis area with zigzag indicator
              SizedBox(
                width: timeAxisWidth,
                child: Stack(
                  children: [
                    // Zigzag indicator aligned to right edge of time axis
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: ZigzagFoldIndicator(
                        color: context.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),

              // Main content area
              Expanded(
                child: Stack(
                  children: [
                    // Background tint
                    Container(
                      decoration: BoxDecoration(
                        color: context.colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.3),
                      ),
                    ),

                    // Compressed hour markers
                    ...List.generate(region.hourCount, (i) {
                      return Positioned(
                        top: i * kCompressedHourHeight,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: context.colorScheme.outlineVariant
                              .withValues(alpha: 0.15),
                        ),
                      );
                    }),

                    // Time range label in center
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingSmall,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: context.colorScheme.outlineVariant
                                .withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.unfold_more,
                              size: 12,
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimeRange(),
                              style: context.textTheme.labelSmall?.copyWith(
                                color: context.colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeRange() {
    final startStr = region.startHour.toString().padLeft(2, '0');
    final endStr = region.endHour.toString().padLeft(2, '0');
    return '$startStr:00 - $endStr:00';
  }
}

/// An animated wrapper for timeline regions that handles expand/collapse.
class AnimatedTimelineRegion extends StatefulWidget {
  const AnimatedTimelineRegion({
    required this.region,
    required this.isExpanded,
    required this.normalHourHeight,
    required this.child,
    super.key,
  });

  /// The compressed region being animated.
  final CompressedRegion region;

  /// Whether the region is currently expanded.
  final bool isExpanded;

  /// Height per hour when expanded (normal view).
  final double normalHourHeight;

  /// The child widget to display (either compressed or normal content).
  final Widget child;

  @override
  State<AnimatedTimelineRegion> createState() => _AnimatedTimelineRegionState();
}

class _AnimatedTimelineRegionState extends State<AnimatedTimelineRegion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late double _collapsedHeight;
  late double _expandedHeight;

  @override
  void initState() {
    super.initState();
    _collapsedHeight = widget.region.hourCount * kCompressedHourHeight;
    _expandedHeight = widget.region.hourCount * widget.normalHourHeight;

    _controller = AnimationController(
      duration: const Duration(milliseconds: AppTheme.animationDuration),
      vsync: this,
    );

    _heightAnimation = Tween<double>(
      begin: _collapsedHeight,
      end: _expandedHeight,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Set initial state without animation
    if (widget.isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(AnimatedTimelineRegion oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update heights if region changed
    if (oldWidget.region != widget.region ||
        oldWidget.normalHourHeight != widget.normalHourHeight) {
      _collapsedHeight = widget.region.hourCount * kCompressedHourHeight;
      _expandedHeight = widget.region.hourCount * widget.normalHourHeight;
      _heightAnimation = Tween<double>(
        begin: _collapsedHeight,
        end: _expandedHeight,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
    }

    // Animate when isExpanded changes
    if (oldWidget.isExpanded != widget.isExpanded) {
      if (widget.isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine the target height for the child based on current state
    final targetHeight = widget.isExpanded ? _expandedHeight : _collapsedHeight;

    return AnimatedBuilder(
      animation: _heightAnimation,
      builder: (context, child) {
        return ClipRect(
          child: SizedBox(
            height: _heightAnimation.value,
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minHeight: targetHeight,
              maxHeight: targetHeight,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
