import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A small coloured tag displaying a category icon and label.
class CategoryTag extends StatelessWidget {
  const CategoryTag({
    required this.label,
    required this.icon,
    required this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: ShowcasePalette.tagText(context),
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: ShowcasePalette.tagText(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// A pill showing the project status icon and label, optionally larger with
/// an expand chevron.
class ProjectStatusPill extends StatelessWidget {
  const ProjectStatusPill({
    required this.status,
    this.large = false,
    super.key,
  });

  final ProjectStatus status;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final statusColor = showcaseProjectStatusColor(context, status);
    final height = large ? 28.0 : 20.0;
    final horizontalPadding = large ? 8.0 : 0.0;
    final verticalPadding = large ? 4.0 : 0.0;

    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: ShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProjectStatusIcon(
            status: status,
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            showcaseProjectStatusLabel(context, status),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: ShowcasePalette.highText(context),
            ),
          ),
          if (large) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.unfold_more_rounded,
              size: 16,
              color: ShowcasePalette.mediumText(context),
            ),
          ],
        ],
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
          size: 16,
          color: showcaseProjectStatusColor(context, status),
        ),
        const SizedBox(width: 4),
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
  const TaskStatePill({required this.status, super.key});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final icon = switch (status) {
      TaskOpen() => Icons.radio_button_unchecked_rounded,
      TaskInProgress() => Icons.play_arrow_rounded,
      TaskGroomed() => Icons.circle_outlined,
      TaskBlocked() => Icons.warning_amber_rounded,
      TaskOnHold() => Icons.pause_circle_outline_rounded,
      TaskDone() => Icons.check_circle_outline_rounded,
      TaskRejected() => Icons.cancel_outlined,
    };

    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: ShowcasePalette.mediumText(context),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: ShowcasePalette.mediumText(context),
            ),
          ),
        ],
      ),
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
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: ShowcasePalette.infoBlue(context),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$count',
        style: tokens.typography.styles.others.caption.copyWith(
          color: ShowcasePalette.tagText(context),
        ),
      ),
    );
  }
}

/// A floating add-project action matching the Widgetbook mobile reference.
class ProjectCreateFab extends StatelessWidget {
  const ProjectCreateFab({
    required this.semanticLabel,
    this.onPressed,
    super.key,
  });

  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(24);

    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: ShowcasePalette.teal(context),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onPressed,
            child: const SizedBox.square(
              dimension: 56,
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  size: 24,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A bordered panel with a header row, divider, and a list of children
/// separated by dividers.
class ShowcasePanel extends StatelessWidget {
  const ShowcasePanel({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    super.key,
  });

  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ShowcasePalette.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: header,
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: ShowcasePalette.border(context),
          ),
          for (var index = 0; index < itemCount; index++) ...[
            itemBuilder(context, index),
            if (index < itemCount - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: ShowcasePalette.border(context),
              ),
          ],
        ],
      ),
    );
  }
}

/// A centred "no results" message.
class NoResultsPane extends StatelessWidget {
  const NoResultsPane({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Text(
        context.messages.projectShowcaseNoResults,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: ShowcasePalette.mediumText(context),
        ),
      ),
    );
  }
}

/// A titled text block with an optional trailing label (e.g. "Updated 2h ago").
class TextSection extends StatelessWidget {
  const TextSection({
    required this.title,
    required this.body,
    this.trailingLabel,
    super.key,
  });

  final String title;
  final String body;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
            children: [
              Text(
                title,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: ShowcasePalette.highText(context),
                ),
              ),
              const Spacer(),
              if (trailingLabel case final trailingLabel?)
                Text(
                  trailingLabel,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: ShowcasePalette.mediumText(context),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: ShowcasePalette.highText(context),
          ),
        ),
      ],
    );
  }
}

/// Formats a relative "Updated X ago" label from a pair of timestamps.
String showcaseUpdatedLabel(
  BuildContext context, {
  required DateTime updatedAt,
  required DateTime currentTime,
}) {
  final difference = currentTime.difference(updatedAt);

  if (difference.isNegative || difference.inHours < 1) {
    final minutes = difference.inMinutes < 1 ? 1 : difference.inMinutes;
    return context.messages.projectShowcaseUpdatedMinutesAgo(minutes);
  }

  return context.messages.projectShowcaseUpdatedHoursAgo(difference.inHours);
}

/// A bullet-point list of recommendation strings.
class RecommendationsList extends StatelessWidget {
  const RecommendationsList({required this.items, super.key});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '•',
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: ShowcasePalette.teal(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: ShowcasePalette.mediumText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
