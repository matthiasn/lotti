import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/widgets/project_health_indicator.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/themes/theme.dart' show numericBadgeFontFeatures;

/// A small coloured tag displaying a category icon and label.
class CategoryTag extends StatelessWidget {
  const CategoryTag({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // User-defined category colors span the full hue/luminance space —
    // a fixed palette text colour collapses to illegible on near-black
    // or near-white backgrounds. Flip to black/white based on the
    // estimated background brightness, mirroring the same pattern used
    // by the category icon tiles in `categories_list_page.dart`.
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final child = _ShowcaseMetaTag(
      label: label,
      icon: icon,
      backgroundColor: color,
      foregroundColor: foreground,
    );

    if (onTap == null) {
      return child;
    }

    return _InteractiveTagSurface(
      borderRadius: tokens.radii.xs,
      onTap: onTap!,
      child: child,
    );
  }
}

/// Compact meta-tag pill showing a project's health [band] (icon + label) in
/// the band's accent color, for the detail header's meta-tag row.
class ProjectHealthBandTag extends StatelessWidget {
  const ProjectHealthBandTag({
    required this.band,
    super.key,
  });

  final ProjectHealthBand band;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = projectHealthBandAttributes(context, band);

    return _ShowcaseMetaTag(
      label: label,
      icon: icon,
      backgroundColor: color.withValues(alpha: 0.24),
      foregroundColor: color,
      borderColor: color.withValues(alpha: 0.42),
    );
  }
}

/// A pill showing the project status icon and label, optionally larger with
/// an expand chevron.
class ProjectStatusPill extends StatelessWidget {
  const ProjectStatusPill({
    required this.status,
    this.large = false,
    this.onTap,
    super.key,
  });

  final ProjectStatus status;
  final bool large;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final statusColor = showcaseProjectStatusColor(context, status);
    if (!large) {
      final accent = switch (status) {
        ProjectOpen() || ProjectArchived() => null,
        _ => statusColor,
      };
      return DsPill(
        variant: accent == null ? DsPillVariant.filled : DsPillVariant.tinted,
        bordered: accent == null,
        color: accent,
        label: showcaseProjectStatusLabel(context, status),
        leading: _ProjectStatusIcon(
          status: status,
          size: tokens.typography.lineHeight.caption,
          color: statusColor,
        ),
        trailing: onTap == null
            ? null
            : Icon(
                LottiIcons.expand,
                size: tokens.typography.lineHeight.caption,
                color: ShowcasePalette.mediumText(context),
              ),
        onTap: onTap,
      );
    }

    final child = Container(
      constraints: BoxConstraints(
        minHeight:
            tokens.typography.lineHeight.subtitle2 + tokens.spacing.step2,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        color: ShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProjectStatusIcon(
            status: status,
            size: tokens.typography.lineHeight.caption,
            color: statusColor,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            showcaseProjectStatusLabel(context, status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: ShowcasePalette.highText(context),
              height: 1,
            ),
          ),
          SizedBox(width: tokens.spacing.step1),
          Icon(
            LottiIcons.expandBoth,
            size: tokens.typography.lineHeight.caption,
            color: ShowcasePalette.mediumText(context),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return _InteractiveTagSurface(
      borderRadius: tokens.radii.badgesPills,
      onTap: onTap!,
      child: child,
    );
  }
}

class _ShowcaseMetaTag extends StatelessWidget {
  const _ShowcaseMetaTag({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
    this.iconWidget,
    this.borderColor,
  }) : assert(
         icon != null || iconWidget != null,
         'Either icon or iconWidget must be provided.',
       );

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;
  final Widget? iconWidget;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      constraints: BoxConstraints(
        minHeight: tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget ??
              Icon(
                icon,
                size: tokens.typography.size.caption,
                color: foregroundColor,
              ),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: foregroundColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An outlined pill with an icon and label, used for project metadata (target
/// date, category, status). Supports an optional `isPlaceholder` style that
/// uses muted text and an optional `onTap` that wraps the pill in an InkWell.
class OutlinedMetaTag extends StatelessWidget {
  const OutlinedMetaTag({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPlaceholder = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPlaceholder;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textColor = isPlaceholder
        ? ShowcasePalette.mediumText(context)
        : ShowcasePalette.lowText(context);

    final child = Container(
      constraints: BoxConstraints(
        minHeight: tokens.spacing.step5 + tokens.spacing.step1,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: tokens.typography.size.caption,
            color: textColor,
          ),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: tokens.typography.styles.others.caption.copyWith(
                color: textColor,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return child;
    }

    return _InteractiveTagSurface(
      borderRadius: tokens.radii.xs,
      onTap: onTap!,
      child: child,
    );
  }
}

class _InteractiveTagSurface extends StatelessWidget {
  const _InteractiveTagSurface({
    required this.borderRadius,
    required this.onTap,
    required this.child,
  });

  final double borderRadius;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact status icon + label used in the project list row.
class ProjectStatusLabel extends StatelessWidget {
  const ProjectStatusLabel({required this.status, super.key});

  final ProjectStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProjectStatusIcon(
          status: status,
          size: tokens.typography.lineHeight.caption,
          color: showcaseProjectStatusColor(context, status),
        ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          showcaseProjectStatusLabel(context, status),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: ShowcasePalette.highText(context),
          ),
        ),
      ],
    );
  }
}

class _ProjectStatusIcon extends StatelessWidget {
  const _ProjectStatusIcon({
    required this.status,
    required this.size,
    required this.color,
  });

  final ProjectStatus status;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final assetName = switch (status) {
      ProjectActive() => 'assets/design_system/project_status_active.svg',
      ProjectCompleted() => 'assets/design_system/project_status_completed.svg',
      ProjectArchived() => 'assets/design_system/project_status_archived.svg',
      _ => null,
    };

    if (assetName != null) {
      return SvgPicture.asset(
        assetName,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return Icon(
      showcaseProjectStatusIcon(status),
      size: size,
      color: color,
    );
  }
}

/// A pill showing a task's status icon and localised label.
class TaskStatePill extends StatelessWidget {
  const TaskStatePill({
    required this.status,
    this.compact = false,
    super.key,
  });

  final TaskStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final labelStyle = tokens.typography.styles.body.bodySmall;
    final labelColor = compact
        ? ShowcasePalette.lowText(context)
        : ShowcasePalette.mediumText(context);
    final glyphSize = tokens.typography.lineHeight.caption;
    final (:iconColor, :assetName, :fallbackIcon) = switch (status) {
      TaskOpen() => (
        iconColor: ShowcasePalette.mediumText(context),
        assetName: 'assets/design_system/task_status_open.svg',
        fallbackIcon: null,
      ),
      TaskInProgress() => (
        iconColor: ShowcasePalette.amber(context),
        assetName: 'assets/design_system/project_status_active.svg',
        fallbackIcon: null,
      ),
      TaskGroomed() => (
        iconColor: ShowcasePalette.timeGreen(context),
        assetName: 'assets/design_system/task_status_groomed.svg',
        fallbackIcon: null,
      ),
      TaskBlocked() => (
        iconColor: ShowcasePalette.error(context),
        assetName: 'assets/design_system/task_status_blocked.svg',
        fallbackIcon: null,
      ),
      TaskOnHold() => (
        iconColor: ShowcasePalette.amber(context),
        assetName: 'assets/design_system/task_status_on_hold.svg',
        fallbackIcon: null,
      ),
      TaskDone() => (
        iconColor: ShowcasePalette.timeGreen(context),
        assetName: 'assets/design_system/project_status_completed.svg',
        fallbackIcon: null,
      ),
      TaskRejected() => (
        iconColor: ShowcasePalette.error(context),
        assetName: null,
        fallbackIcon: LottiIcons.closeCircled,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetName != null)
          SvgPicture.asset(
            assetName,
            width: glyphSize,
            height: glyphSize,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          )
        else if (fallbackIcon != null)
          Icon(
            fallbackIcon,
            size: glyphSize,
            color: iconColor,
          ),
        SizedBox(width: tokens.spacing.step1),
        Text(
          label,
          style: labelStyle.copyWith(
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

/// A circular badge with a count, used in panel headers.
class CountDotBadge extends StatelessWidget {
  const CountDotBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      width: tokens.spacing.step5 + tokens.spacing.step1,
      height: tokens.spacing.step5 + tokens.spacing.step1,
      decoration: BoxDecoration(
        color: ShowcasePalette.infoBlue(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: ShowcasePalette.tagText(context),
          fontFeatures: numericBadgeFontFeatures,
        ),
      ),
    );
  }
}
