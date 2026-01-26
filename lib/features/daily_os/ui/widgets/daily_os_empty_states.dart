import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

/// A warm, inviting empty state for the timeline section.
/// Features a minimal clock/timeline illustration with subtle animation.
class TimelineEmptyState extends StatefulWidget {
  const TimelineEmptyState({super.key});

  @override
  State<TimelineEmptyState> createState() => _TimelineEmptyStateState();
}

class _TimelineEmptyStateState extends State<TimelineEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideUp = Tween<double>(begin: 12, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _fadeIn.value,
          child: Transform.translate(
            offset: Offset(0, _slideUp.value),
            child: ModernBaseCard(
              margin: const EdgeInsets.all(AppTheme.spacingLarge),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Timeline illustration
                  SizedBox(
                    width: 120,
                    height: 70,
                    child: CustomPaint(
                      painter: _TimelineIllustrationPainter(
                        isDark: isDark,
                        progress: _fadeIn.value,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    context.messages.dailyOsNoTimeline,
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    context.messages.dailyOsNoTimelineHint,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Timeline illustration painter - shows a simple timeline with placeholder blocks.
class _TimelineIllustrationPainter extends CustomPainter {
  _TimelineIllustrationPainter({
    required this.isDark,
    required this.progress,
  });

  final bool isDark;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);

    final accentColor = isDark
        ? const Color(0xFF6C5CE7).withValues(alpha: 0.4)
        : const Color(0xFF6C5CE7).withValues(alpha: 0.25);

    // Vertical timeline line
    final linePaint = Paint()
      ..color = baseColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      const Offset(20, 8),
      Offset(20, size.height - 8),
      linePaint,
    );

    // Time markers (circles on the line)
    final markerPaint = Paint()..color = baseColor;
    final positions = [0.15, 0.45, 0.75];

    for (var i = 0; i < positions.length; i++) {
      final y = 8 + (size.height - 16) * positions[i];
      canvas.drawCircle(Offset(20, y), 4, markerPaint);

      // Placeholder blocks extending from markers
      final blockWidth = [70.0, 50.0, 85.0][i] * progress;
      final blockPaint = Paint()
        ..color = i == 1 ? accentColor : baseColor
        ..style = PaintingStyle.fill;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(32, y - 6, blockWidth, 12),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, blockPaint);
    }

    // Dashed "add" indicator
    if (progress > 0.5) {
      final dashPaint = Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.2 * (progress - 0.5) * 2)
            : Colors.black.withValues(alpha: 0.1 * (progress - 0.5) * 2)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      const dashY = 8.0 + (70.0 - 16) * 0.92;
      const dashLength = 4.0;
      const dashGap = 3.0;

      var x = 32.0;
      while (x < 100) {
        canvas.drawLine(
          Offset(x, dashY),
          Offset(x + dashLength, dashY),
          dashPaint,
        );
        x += dashLength + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(_TimelineIllustrationPainter oldDelegate) {
    return isDark != oldDelegate.isDark || progress != oldDelegate.progress;
  }
}

/// A warm, inviting empty state for the budgets section.
/// Features animated pie chart segments that invite interaction.
class BudgetsEmptyState extends StatefulWidget {
  const BudgetsEmptyState({required this.date, super.key});

  final DateTime date;

  @override
  State<BudgetsEmptyState> createState() => _BudgetsEmptyStateState();
}

class _BudgetsEmptyStateState extends State<BudgetsEmptyState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleIn;
  late final Animation<double> _rotate;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    _scaleIn = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _rotate = Tween<double>(begin: -0.1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Muted, sophisticated color palette
    final colors = isDark
        ? [
            const Color(0xFF6C5CE7),
            const Color(0xFF00B894),
            const Color(0xFFFDAA5C),
            const Color(0xFFE17055),
          ]
        : [
            const Color(0xFF74B9FF),
            const Color(0xFF55EFC4),
            const Color(0xFFFDCB6E),
            const Color(0xFFFF7675),
          ];

    return ModernBaseCard(
      margin: const EdgeInsets.all(AppTheme.spacingLarge),
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated donut chart illustration
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleIn.value,
                child: Transform.rotate(
                  angle: _rotate.value,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _DonutChartPainter(
                        colors: colors,
                        isDark: isDark,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          Text(
            context.messages.dailyOsNoBudgets,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            context.messages.dailyOsNoBudgetsHint,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Stylized add button
          _AddBudgetButton(
            onPressed: () => AddBudgetSheet.show(context, widget.date),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// Donut chart painter for budget empty state.
class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.colors,
    required this.isDark,
  });

  final List<Color> colors;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    // Draw dashed segments suggesting where budgets will go
    final segmentAngles = [0.28, 0.22, 0.3, 0.2];
    var startAngle = -math.pi / 2;

    for (var i = 0; i < segmentAngles.length; i++) {
      final sweepAngle = segmentAngles[i] * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i].withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle + 0.04, // Small gap
        sweepAngle - 0.08, // Gap on both sides
        false,
        paint,
      );

      startAngle += sweepAngle;
    }

    // Center circle with subtle gradient
    final centerPaint = Paint()
      ..shader = RadialGradient(
        colors: isDark
            ? [const Color(0xFF2D2D44), const Color(0xFF1E1E2E)]
            : [Colors.white, const Color(0xFFF8F9FA)],
      ).createShader(
        Rect.fromCircle(center: center, radius: radius - strokeWidth - 4),
      );
    canvas.drawCircle(center, radius - strokeWidth - 4, centerPaint);

    // Plus icon in center
    final plusPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const plusSize = 14.0;
    canvas
      ..drawLine(
        Offset(center.dx - plusSize / 2, center.dy),
        Offset(center.dx + plusSize / 2, center.dy),
        plusPaint,
      )
      ..drawLine(
        Offset(center.dx, center.dy - plusSize / 2),
        Offset(center.dx, center.dy + plusSize / 2),
        plusPaint,
      );
  }

  @override
  bool shouldRepaint(_DonutChartPainter oldDelegate) => false;
}

/// Stylized add budget button.
class _AddBudgetButton extends StatefulWidget {
  const _AddBudgetButton({
    required this.onPressed,
    required this.isDark,
  });

  final VoidCallback onPressed;
  final bool isDark;

  @override
  State<_AddBudgetButton> createState() => _AddBudgetButtonState();
}

class _AddBudgetButtonState extends State<_AddBudgetButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: widget.isDark
                  ? [
                      const Color(0xFF6C5CE7),
                      const Color(0xFF5B4BD5),
                    ]
                  : [
                      const Color(0xFF6C5CE7),
                      const Color(0xFF5758BB),
                    ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C5CE7).withValues(
                  alpha: _isHovered ? 0.4 : 0.25,
                ),
                blurRadius: _isHovered ? 16 : 12,
                offset: Offset(0, _isHovered ? 6 : 4),
              ),
            ],
          ),
          transform: _isHovered
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.messages.dailyOsAddBudget,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
