import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/avatars/design_system_avatar.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/navigation/design_system_navigation_tab_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

class TaskShowcaseCategoryChip extends StatelessWidget {
  const TaskShowcaseCategoryChip({
    required this.label,
    required this.icon,
    required this.colorHex,
    super.key,
  });

  final String label;
  final IconData icon;
  final String colorHex;

  @override
  Widget build(BuildContext context) {
    final bg = colorFromCssHex(colorHex);
    return CategoryTag(
      label: label,
      icon: icon,
      color: bg,
    );
  }
}

class TaskShowcaseLabelChip extends StatelessWidget {
  const TaskShowcaseLabelChip({
    required this.label,
    required this.color,
    this.outlined = false,
    super.key,
  });

  final String label;
  final Color color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 20,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: tokens.typography.styles.others.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class TaskShowcaseMetaChip extends StatelessWidget {
  const TaskShowcaseMetaChip({
    required this.icon,
    required this.label,
    super.key,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 20,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: TaskShowcasePalette.mediumText(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: TaskShowcasePalette.mediumText(context),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskShowcasePriorityGlyph extends StatelessWidget {
  const TaskShowcasePriorityGlyph({
    required this.priority,
    this.size = 16,
    super.key,
  });

  final TaskPriority priority;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (priority) {
      TaskPriority.p0Urgent => 'assets/design_system/task_priority_p0.svg',
      TaskPriority.p1High => 'assets/design_system/task_priority_high.svg',
      TaskPriority.p2Medium => 'assets/design_system/task_priority_medium.svg',
      TaskPriority.p3Low => 'assets/design_system/task_priority_low.svg',
    };

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
    );
  }
}

class TaskShowcaseStatusGlyph extends StatelessWidget {
  const TaskShowcaseStatusGlyph({
    required this.status,
    this.size = 16,
    super.key,
  });

  final TaskStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = switch (status) {
      TaskOpen() => 'assets/design_system/task_status_open.svg',
      TaskGroomed() => 'assets/design_system/task_status_groomed.svg',
      TaskInProgress() => 'assets/design_system/task_status_in_progress.svg',
      TaskBlocked() => 'assets/design_system/task_status_blocked.svg',
      TaskOnHold() => 'assets/design_system/task_status_on_hold.svg',
      TaskDone() => 'assets/design_system/task_status_done.svg',
      TaskRejected() => 'assets/design_system/task_status_rejected.svg',
    };
    final color = switch (status) {
      TaskOpen() => TaskShowcasePalette.mediumText(context),
      TaskGroomed() || TaskInProgress() => TaskShowcasePalette.info(context),
      TaskBlocked() || TaskRejected() => TaskShowcasePalette.error(context),
      TaskOnHold() => TaskShowcasePalette.warning(context),
      TaskDone() => TaskShowcasePalette.success(context),
    };

    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}

class TaskShowcaseStatusLabel extends StatelessWidget {
  const TaskShowcaseStatusLabel({
    required this.status,
    this.expanded = false,
    super.key,
  });

  final TaskStatus status;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final textColor = TaskShowcasePalette.highText(context);

    return Container(
      height: expanded ? 28 : null,
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? tokens.spacing.step3 : 0,
        vertical: expanded ? tokens.spacing.step2 : 0,
      ),
      decoration: expanded
          ? BoxDecoration(
              color: TaskShowcasePalette.subtleFill(context),
              borderRadius: BorderRadius.circular(20),
            )
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcaseStatusGlyph(status: status),
          SizedBox(
            width: expanded ? tokens.spacing.step2 : tokens.spacing.step1,
          ),
          Text(
            label,
            style:
                (expanded
                        ? tokens.typography.styles.subtitle.subtitle2
                        : tokens.typography.styles.body.bodySmall)
                    .copyWith(
                      color: textColor,
                    ),
          ),
          if (expanded) ...[
            SizedBox(width: tokens.spacing.step1),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: TaskShowcasePalette.mediumText(context),
            ),
          ],
        ],
      ),
    );
  }
}

class TaskShowcaseCard extends StatelessWidget {
  const TaskShowcaseCard({
    required this.child,
    this.title,
    this.trailing,
    this.padding,
    super.key,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.all(tokens.spacing.step4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(
                            color: TaskShowcasePalette.highText(context),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  ...switch (trailing) {
                    final trailing? => [trailing],
                    null => const <Widget>[],
                  },
                ],
              ),
              SizedBox(height: tokens.spacing.step4),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class TaskShowcaseSectionPill extends StatelessWidget {
  const TaskShowcaseSectionPill({
    required this.icon,
    required this.label,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final foreground = active
        ? Colors.black
        : TaskShowcasePalette.mediumText(context);
    final background = active
        ? TaskShowcasePalette.accent(context)
        : TaskShowcasePalette.subtleFill(context);

    return Container(
      height: 24,
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          SizedBox(width: tokens.spacing.step2),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskShowcaseHeroBanner extends StatelessWidget {
  const TaskShowcaseHeroBanner({
    this.height = 180,
    super.key,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF7ED5FF),
              Color(0xFF16457E),
              Color(0xFFFFB05B),
            ],
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.18),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -40,
                bottom: -60,
                child: Container(
                  width: height * 0.9,
                  height: height * 0.9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -10,
                top: 18,
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: height * 0.82,
                    height: height * 0.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                top: 26,
                child: Transform.rotate(
                  angle: 0.1,
                  child: Container(
                    width: height * 0.36,
                    height: height * 0.72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: height * 0.34,
                top: height * 0.34,
                right: height * 0.18,
                child: const _TaskShowcaseHandshakeBridge(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskShowcaseHandshakeBridge extends StatelessWidget {
  const _TaskShowcaseHandshakeBridge();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.7,
      child: CustomPaint(
        painter: _TaskShowcaseBridgePainter(),
      ),
    );
  }
}

class _TaskShowcaseBridgePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final neon = Paint()
      ..color = const Color(0xFF7BE7FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = const Color(0xFF7BE7FF).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final bridge = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.32,
        size.width * 0.55,
        size.height * 0.52,
      )
      ..quadraticBezierTo(
        size.width * 0.74,
        size.height * 0.66,
        size.width,
        size.height * 0.2,
      );
    canvas
      ..drawPath(bridge, glow)
      ..drawPath(bridge, neon);

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.24)
      ..strokeWidth = 1;
    for (var index = 0; index < 5; index++) {
      final dy = size.height * (0.15 + index * 0.16);
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width * 0.42, dy + 12),
        grid,
      );
    }

    final nodePaint = Paint()..color = const Color(0xFFFFC566);
    for (final x in [size.width * 0.28, size.width * 0.45, size.width * 0.64]) {
      canvas.drawCircle(Offset(x, size.height * 0.46), 3.5, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TaskShowcaseDesktopTopBar extends StatelessWidget {
  const TaskShowcaseDesktopTopBar({
    required this.title,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      height: 80,
      padding: const EdgeInsets.fromLTRB(32, 20, 32, 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: TaskShowcasePalette.border(context)),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: TaskShowcasePalette.highText(context),
            ),
          ),
          const Spacer(),
          Icon(
            Icons.notifications_none_rounded,
            color: TaskShowcasePalette.highText(context),
            size: 28,
          ),
          const SizedBox(width: 16),
          const DesignSystemAvatar(
            image: AssetImage('assets/design_system/avatar_placeholder.png'),
          ),
        ],
      ),
    );
  }
}

class TaskShowcaseDesktopActionBar extends StatelessWidget {
  const TaskShowcaseDesktopActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          DesignSystemNavigationFrostedSurface(
            borderRadius: BorderRadius.circular(tokens.radii.xl),
            padding: EdgeInsets.all(tokens.spacing.step3),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 60,
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 20,
                          color: TaskShowcasePalette.highText(context),
                        ),
                        SizedBox(width: tokens.spacing.step2),
                        Text(
                          context.messages.addActionAddTimer,
                          style: tokens.typography.styles.subtitle.subtitle2
                              .copyWith(
                                color: TaskShowcasePalette.highText(context),
                              ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: tokens.spacing.step3),
                  for (final icon in const [
                    Icons.checklist_rounded,
                    Icons.image_outlined,
                    Icons.mic_none_rounded,
                    Icons.subdirectory_arrow_right_rounded,
                  ]) ...[
                    _TaskShowcaseRoundAction(icon: icon),
                    SizedBox(width: tokens.spacing.step3),
                  ],
                  // Reserve room equal to the overlaid FAB so the last
                  // action never sits behind it.
                  SizedBox(width: 56 + tokens.spacing.step5),
                ],
              ),
            ),
          ),
          const Positioned(
            right: 0,
            bottom: 0,
            child: _TaskShowcaseDetailFab(),
          ),
        ],
      ),
    );
  }
}

class _TaskShowcaseDetailFab extends StatelessWidget {
  const _TaskShowcaseDetailFab();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: 56,
      height: 56,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Showcase-only: delegates to the real design-system FAB so the
          // shape, size and colour match production; no callback is wired
          // because this widget lives inside the widgetbook showcase.
          DesignSystemFloatingActionButton(
            semanticLabel: context.messages.addActionAddTask,
            onPressed: () {},
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: tokens.colors.alert.error.defaultColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: tokens.colors.background.level01,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskShowcaseRoundAction extends StatelessWidget {
  const _TaskShowcaseRoundAction({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: TaskShowcasePalette.highText(context),
      ),
    );
  }
}

class TaskShowcaseProfileButton extends StatelessWidget {
  const TaskShowcaseProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return DesignSystemNavigationFrostedSurface(
      borderRadius: BorderRadius.circular(999),
      child: const SizedBox.square(
        dimension: 60,
        child: Center(
          child: DesignSystemAvatar(
            image: AssetImage('assets/design_system/avatar_placeholder.png'),
          ),
        ),
      ),
    );
  }
}

class TaskShowcaseWaveform extends StatelessWidget {
  const TaskShowcaseWaveform({
    required this.samples,
    super.key,
  });

  final List<double> samples;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      height: 32,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var index = 0; index < samples.length; index++) ...[
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: math.max(2, tokens.spacing.step1 + 1),
                  height: 8 + (samples[index] * 24),
                  decoration: BoxDecoration(
                    color: TaskShowcasePalette.accent(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            if (index != samples.length - 1)
              SizedBox(width: tokens.spacing.step1 / 2),
          ],
        ],
      ),
    );
  }
}
