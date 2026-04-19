import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';

/// Chip model for label-like badges rendered in the header's chip row.
///
/// A filled chip paints its background with [color] at full opacity and draws
/// the label in `text.onInteractiveAlert`. An outlined chip uses a transparent
/// fill with a [color] border and the label painted in [color].
@immutable
class DesktopTaskHeaderLabel {
  const DesktopTaskHeaderLabel({
    required this.id,
    required this.label,
    required this.color,
    this.filled = false,
    this.icon,
  });

  final String id;
  final String label;
  final Color color;
  final bool filled;
  final IconData? icon;
}

/// Project reference shown directly under the title.
@immutable
class DesktopTaskHeaderProject {
  const DesktopTaskHeaderProject({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Work category chip rendered as the first entry of the chip row.
@immutable
class DesktopTaskHeaderCategory {
  const DesktopTaskHeaderCategory({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;
}

/// Due-date chip rendered next to the category chip.
@immutable
class DesktopTaskHeaderDueDate {
  const DesktopTaskHeaderDueDate({
    required this.label,
    this.isUrgent = false,
  });

  final String label;
  final bool isUrgent;
}

/// View model passed to the presentational [DesktopTaskHeader]. Callers build
/// it from real domain data (the Riverpod-aware connector) or from fixtures
/// (Widgetbook, tests). Keeps the header free of Riverpod or repository
/// dependencies so it can be exercised in isolation.
@immutable
class DesktopTaskHeaderData {
  const DesktopTaskHeaderData({
    required this.title,
    required this.priority,
    required this.status,
    this.project,
    this.category,
    this.dueDate,
    this.labels = const [],
  });

  final String title;
  final TaskPriority priority;
  final TaskStatus status;
  final DesktopTaskHeaderProject? project;
  final DesktopTaskHeaderCategory? category;
  final DesktopTaskHeaderDueDate? dueDate;
  final List<DesktopTaskHeaderLabel> labels;
}

/// Presentational desktop-first task header. Holds only local UI state
/// (hover/edit) and emits callbacks — no Riverpod, no repositories.
class DesktopTaskHeader extends StatefulWidget {
  const DesktopTaskHeader({
    required this.data,
    required this.onTitleSaved,
    this.onPriorityTap,
    this.onStatusTap,
    this.onProjectTap,
    this.onCategoryTap,
    this.onDueDateTap,
    this.onLabelTap,
    this.onEllipsisTap,
    this.initialHover = false,
    this.initialEditing = false,
    super.key,
  });

  final DesktopTaskHeaderData data;
  final ValueChanged<String> onTitleSaved;
  final VoidCallback? onPriorityTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onProjectTap;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onDueDateTap;
  final ValueChanged<DesktopTaskHeaderLabel>? onLabelTap;
  final VoidCallback? onEllipsisTap;

  /// Force the hover affordance visible on first build. Primarily used by
  /// Widgetbook and tests where no real pointer hover is available.
  final bool initialHover;

  /// Force the inline editor open on first build. Same rationale as
  /// [initialHover].
  final bool initialEditing;

  @override
  State<DesktopTaskHeader> createState() => _DesktopTaskHeaderState();
}

class _DesktopTaskHeaderState extends State<DesktopTaskHeader> {
  late bool _isHovering = widget.initialHover;
  late bool _isEditing = widget.initialEditing;
  late final TextEditingController _titleController;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.data.title);
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant DesktopTaskHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isEditing && oldWidget.data.title != widget.data.title) {
      _titleController.text = widget.data.title;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _beginEdit() {
    if (_isEditing) return;
    setState(() {
      _titleController.text = widget.data.title;
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
      _isEditing = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocusNode.requestFocus();
    });
  }

  void _cancelEdit() {
    setState(() {
      _titleController.text = widget.data.title;
      _isEditing = false;
    });
  }

  void _commitEdit() {
    final next = _titleController.text.trim();
    setState(() => _isEditing = false);
    if (next.isNotEmpty && next != widget.data.title) {
      widget.onTitleSaved(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopRow(context),
          SizedBox(height: tokens.spacing.step3),
          _buildChipRow(context),
        ],
      ),
    );
  }

  Widget _buildTopRow(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleCluster(context),
              if (widget.data.project != null) ...[
                SizedBox(height: tokens.spacing.step1),
                _ProjectLine(
                  project: widget.data.project!,
                  onTap: widget.onProjectTap,
                ),
              ],
            ],
          ),
        ),
        if (widget.onEllipsisTap != null)
          _EllipsisButton(onTap: widget.onEllipsisTap!),
      ],
    );
  }

  Widget _buildTitleCluster(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: _InlineTitle(
            controller: _titleController,
            focusNode: _titleFocusNode,
            title: widget.data.title,
            isEditing: _isEditing,
            isHovering: _isHovering,
            onHoverChanged: (hovering) {
              if (_isEditing || hovering == _isHovering) return;
              setState(() => _isHovering = hovering);
            },
            onEditRequested: _beginEdit,
            onCommit: _commitEdit,
            onCancel: _cancelEdit,
          ),
        ),
        SizedBox(width: context.designTokens.spacing.step3),
        _PriorityBadge(
          priority: widget.data.priority,
          onTap: widget.onPriorityTap,
        ),
      ],
    );
  }

  Widget _buildChipRow(BuildContext context) {
    final tokens = context.designTokens;
    final hasAny =
        widget.data.category != null ||
        widget.data.dueDate != null ||
        widget.data.labels.isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: hasAny
              ? Wrap(
                  spacing: tokens.spacing.step3,
                  runSpacing: tokens.spacing.step2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.data.category != null)
                      _CategoryChip(
                        category: widget.data.category!,
                        onTap: widget.onCategoryTap,
                      ),
                    if (widget.data.dueDate != null)
                      _DueDateChip(
                        dueDate: widget.data.dueDate!,
                        onTap: widget.onDueDateTap,
                      ),
                    for (final label in widget.data.labels)
                      _LabelChip(
                        label: label,
                        onTap: widget.onLabelTap == null
                            ? null
                            : () => widget.onLabelTap!(label),
                      ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        SizedBox(width: tokens.spacing.step3),
        _StatusDropdown(
          status: widget.data.status,
          onTap: widget.onStatusTap,
        ),
      ],
    );
  }
}

class _InlineTitle extends StatelessWidget {
  const _InlineTitle({
    required this.controller,
    required this.focusNode,
    required this.title,
    required this.isEditing,
    required this.isHovering,
    required this.onHoverChanged,
    required this.onEditRequested,
    required this.onCommit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;
  final bool isEditing;
  final bool isHovering;
  final ValueChanged<bool> onHoverChanged;
  final VoidCallback onEditRequested;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  static const _capsuleRadius = 8.0;
  static const _capsuleHeight = 28.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final titleStyle = tokens.typography.styles.heading.heading3.copyWith(
      color: TaskShowcasePalette.highText(context),
    );
    final showCapsule = isEditing || isHovering;

    return MouseRegion(
      onEnter: (_) => onHoverChanged(true),
      onExit: (_) => onHoverChanged(false),
      cursor: isEditing ? SystemMouseCursors.text : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        constraints: const BoxConstraints(minHeight: _capsuleHeight),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step1,
          vertical: tokens.spacing.step1,
        ),
        decoration: BoxDecoration(
          color: showCapsule ? tokens.colors.surface.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(_capsuleRadius),
          border: isEditing
              ? Border.all(color: tokens.colors.interactive.enabled)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: isEditing
                  ? _EditingField(
                      controller: controller,
                      focusNode: focusNode,
                      style: titleStyle,
                      onCommit: onCommit,
                      onCancel: onCancel,
                    )
                  : _ViewTitle(
                      title: title,
                      style: titleStyle,
                      onTap: onEditRequested,
                    ),
            ),
            SizedBox(width: tokens.spacing.step3),
            if (isEditing)
              _EditActions(onCommit: onCommit, onCancel: onCancel)
            else
              _EditPencil(
                visible: isHovering,
                onTap: onEditRequested,
              ),
          ],
        ),
      ),
    );
  }
}

class _ViewTitle extends StatelessWidget {
  const _ViewTitle({
    required this.title,
    required this.style,
    required this.onTap,
  });

  final String title;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      ),
    );
  }
}

class _EditingField extends StatelessWidget {
  const _EditingField({
    required this.controller,
    required this.focusNode,
    required this.style,
    required this.onCommit,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextStyle style;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _CommitIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _CommitIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CommitIntent: CallbackAction<_CommitIntent>(
            onInvoke: (_) {
              onCommit();
              return null;
            },
          ),
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) {
              onCancel();
              return null;
            },
          ),
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          style: style,
          cursorColor: context.designTokens.colors.interactive.enabled,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onCommit(),
          decoration: const InputDecoration(
            border: InputBorder.none,
            isDense: true,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }
}

class _CommitIntent extends Intent {
  const _CommitIntent();
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}

class _EditActions extends StatelessWidget {
  const _EditActions({required this.onCommit, required this.onCancel});

  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconAction(
          icon: Icons.check_rounded,
          color: tokens.colors.alert.success.defaultColor,
          semanticLabel: MaterialLocalizations.of(context).okButtonLabel,
          onTap: onCommit,
        ),
        SizedBox(width: tokens.spacing.step2),
        _IconAction(
          icon: Icons.close_rounded,
          color: TaskShowcasePalette.mediumText(context),
          semanticLabel: MaterialLocalizations.of(context).cancelButtonLabel,
          onTap: onCancel,
        ),
      ],
    );
  }
}

class _EditPencil extends StatelessWidget {
  const _EditPencil({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 120),
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: _IconAction(
          icon: Icons.edit_outlined,
          color: TaskShowcasePalette.mediumText(context),
          semanticLabel: MaterialLocalizations.of(
            context,
          ).modalBarrierDismissLabel,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: SizedBox.square(
        dimension: 24,
        child: Icon(icon, size: 20, color: color, semanticLabel: semanticLabel),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.priority, this.onTap});

  final TaskPriority priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final content = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcasePriorityGlyph(priority: priority, size: 20),
          SizedBox(width: tokens.spacing.step2),
          Text(
            priority.short,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.highText(context),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _EllipsisButton extends StatelessWidget {
  const _EllipsisButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      iconSize: 24,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      icon: Icon(
        Icons.more_vert_rounded,
        color: TaskShowcasePalette.mediumText(context),
      ),
    );
  }
}

class _ProjectLine extends StatelessWidget {
  const _ProjectLine({required this.project, this.onTap});

  final DesktopTaskHeaderProject project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          project.icon ?? Icons.folder_outlined,
          size: 12,
          color: TaskShowcasePalette.lowText(context),
        ),
        SizedBox(width: tokens.spacing.step2),
        Flexible(
          child: Text(
            project.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: TaskShowcasePalette.lowText(context),
            ),
          ),
        ),
      ],
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.xs),
      child: child,
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, this.onTap});

  final DesktopTaskHeaderCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: category.color,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.icon != null) ...[
            Icon(
              category.icon,
              size: 12,
              color: tokens.colors.text.onInteractiveAlert,
            ),
            SizedBox(width: tokens.spacing.step1),
          ],
          Text(
            category.label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.onInteractiveAlert,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _DueDateChip extends StatelessWidget {
  const _DueDateChip({required this.dueDate, this.onTap});

  final DesktopTaskHeaderDueDate dueDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = dueDate.isUrgent
        ? TaskShowcasePalette.error(context)
        : TaskShowcasePalette.lowText(context);
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.alarm_rounded, size: 12, color: color),
          SizedBox(width: tokens.spacing.step1),
          Text(
            dueDate.label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, this.onTap});

  final DesktopTaskHeaderLabel label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textColor = label.filled
        ? tokens.colors.text.onInteractiveAlert
        : label.color;
    final content = Container(
      height: 20,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: label.filled ? label.color : Colors.transparent,
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: label.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label.icon != null) ...[
            Icon(label.icon, size: 12, color: textColor),
            SizedBox(width: tokens.spacing.step1),
          ],
          Text(
            label.label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({required this.status, this.onTap});

  final TaskStatus status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final label = status.localizedLabel(context);
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        color: TaskShowcasePalette.subtleFill(context),
        borderRadius: BorderRadius.circular(tokens.radii.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcaseStatusGlyph(status: status),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: TaskShowcasePalette.highText(context),
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Icon(
            Icons.unfold_more_rounded,
            size: 16,
            color: TaskShowcasePalette.mediumText(context),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xl),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
