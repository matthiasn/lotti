import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Project reference shown in the classification row. When the task has no
/// project, the header still renders a subdued placeholder in the same slot
/// whose `onTap` still hits [DesktopTaskHeader.onProjectTap] so users can
/// attach one — the connector gates the actual picker on a linked category.
@immutable
class DesktopTaskHeaderProject {
  const DesktopTaskHeaderProject({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Work category chip rendered as the leading entry of the classification
/// row.
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

/// Urgency levels for the due-date chip. `today` paints orange; `overdue`
/// paints red; `normal` uses the same subdued outline as the other caption
/// chips.
enum DesktopTaskHeaderDueUrgency { normal, today, overdue }

/// Due-date chip rendered in the metadata row.
@immutable
class DesktopTaskHeaderDueDate {
  const DesktopTaskHeaderDueDate({
    required this.label,
    this.urgency = DesktopTaskHeaderDueUrgency.normal,
  });

  final String label;
  final DesktopTaskHeaderDueUrgency urgency;
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

  /// Label definitions straight from the entity cache. The header renders
  /// each as a small outlined chip with a leading color dot (so the label's
  /// color stays legible while the text is still high-emphasis primary).
  final List<LabelDefinition> labels;
}

/// Presentational desktop-first task header built as three explicit lines:
///
/// 1. Title — read-only `Text` that transforms into an inline editor on tap.
/// 2. Classification — category / project / labels in a wrapping row.
/// 3. Metadata — due date / estimate / priority / status in a wrapping row.
///
/// Holds only local UI state (edit) and emits callbacks — no Riverpod, no
/// repositories.
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
    this.onAddLabelTap,
    this.estimateSlot,
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
  final ValueChanged<LabelDefinition>? onLabelTap;

  /// Tap handler for the "Add label" placeholder chip shown when no labels
  /// are assigned. Typically opens the label-selector modal.
  final VoidCallback? onAddLabelTap;

  /// Slot for the estimate affordance. The connector injects a Riverpod-aware
  /// estimate chip here so the header itself stays framework free. When
  /// `null` the metadata row simply omits the estimate entry — in practice
  /// the connector always supplies a slot.
  final Widget? estimateSlot;

  /// Force the inline editor open on first build. Used by Widgetbook / tests
  /// to pin the editing state without simulating a tap.
  final bool initialEditing;

  @override
  State<DesktopTaskHeader> createState() => _DesktopTaskHeaderState();
}

class _DesktopTaskHeaderState extends State<DesktopTaskHeader> {
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
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleLine(context),
          SizedBox(height: tokens.spacing.step3),
          _buildClassificationLine(context),
          SizedBox(height: tokens.spacing.step2),
          _buildMetadataLine(context),
        ],
      ),
    );
  }

  Widget _buildTitleLine(BuildContext context) {
    final tokens = context.designTokens;
    final style = tokens.typography.styles.heading.heading3.copyWith(
      color: TaskShowcasePalette.highText(context),
    );
    if (_isEditing) {
      return _TitleEditor(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: style,
        onCommit: _commitEdit,
        onCancel: _cancelEdit,
      );
    }
    return _TitleReadOnly(
      title: widget.data.title,
      style: style,
      onTap: _beginEdit,
    );
  }

  Widget _buildClassificationLine(BuildContext context) {
    final tokens = context.designTokens;
    final categoryChip = widget.data.category != null
        ? _CategoryChip(
            category: widget.data.category!,
            onTap: widget.onCategoryTap,
          )
        : _PlaceholderChip(
            icon: Icons.category_outlined,
            label: context.messages.taskCategoryUnassignedLabel,
            onTap: widget.onCategoryTap,
          );
    final projectChip = _ProjectChip(
      project: widget.data.project,
      onTap: widget.onProjectTap,
    );
    // Flat Wrap — Category · Project · Label1 · Label2 · Label3. Dots
    // are the only separators; individual labels read as one group because
    // they sit in natural reading order after the second dot.
    final chips = <Widget>[
      categoryChip,
      const _GroupSeparator(),
      projectChip,
      const _GroupSeparator(),
      if (widget.data.labels.isEmpty)
        _PlaceholderChip(
          icon: Icons.label_outline_rounded,
          label: context.messages.tasksAddLabelButton,
          onTap: widget.onAddLabelTap,
        )
      else
        for (final label in widget.data.labels)
          _LabelChip(
            label: label,
            onTap: widget.onLabelTap == null
                ? null
                : () => widget.onLabelTap!(label),
          ),
    ];

    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: chips,
    );
  }

  Widget _buildMetadataLine(BuildContext context) {
    final tokens = context.designTokens;
    // Two semantic groups. Each group is a `Row(mainAxisSize: min)` so the
    // chips inside it always stay on the same line — only the outer
    // LayoutBuilder branch below decides whether the two groups share one
    // row or stack vertically.
    final leftGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.data.dueDate != null)
          _DueDateChip(
            dueDate: widget.data.dueDate!,
            onTap: widget.onDueDateTap,
          )
        else
          _PlaceholderChip(
            icon: Icons.alarm_rounded,
            label: context.messages.taskNoDueDateLabel,
            onTap: widget.onDueDateTap,
          ),
        SizedBox(width: tokens.spacing.step2),
        _PriorityBadge(
          priority: widget.data.priority,
          onTap: widget.onPriorityTap,
        ),
      ],
    );
    final rightGroup = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.estimateSlot != null) ...[
          widget.estimateSlot!,
          SizedBox(width: tokens.spacing.step4),
        ],
        _StatusDropdown(
          status: widget.data.status,
          onTap: widget.onStatusTap,
        ),
      ],
    );
    // `Wrap(alignment: spaceBetween)` doesn't actually space the two
    // groups apart because Wrap shrink-wraps its main-axis size. Instead
    // we branch on available width: above the breakpoint both groups fit
    // side-by-side in a Row(spaceBetween); below it they stack into a
    // Column. The breakpoint scales with the text scaler so accessibility
    // text sizes break into two rows at wider viewports rather than
    // overflowing.
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final breakpoint = 520.0 * scale;
        if (constraints.maxWidth >= breakpoint) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [leftGroup, rightGroup],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leftGroup,
            SizedBox(height: tokens.spacing.step2),
            rightGroup,
          ],
        );
      },
    );
  }
}

/// Subtle low-emphasis vertical rule between classification groups
/// (category | project | labels). Shrink-wrapped to its glyph width so it
/// participates in the outer `Wrap` as a narrow child rather than taking
/// the full row.
class _GroupSeparator extends StatelessWidget {
  const _GroupSeparator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '|',
      style: TextStyle(
        fontSize: 8,
        height: 1,
        color: TaskShowcasePalette.lowText(context).withValues(alpha: 0.3),
      ),
    );
  }
}

class _TitleReadOnly extends StatelessWidget {
  const _TitleReadOnly({
    required this.title,
    required this.style,
    required this.onTap,
  });

  final String title;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Text(title, softWrap: true, style: style),
      ),
    );
  }
}

class _TitleEditor extends StatelessWidget {
  const _TitleEditor({
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

  static const _capsuleRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.surface.hover,
        borderRadius: BorderRadius.circular(_capsuleRadius),
        border: Border.all(color: tokens.colors.interactive.enabled),
      ),
      child: Row(
        children: [
          Expanded(
            child: Shortcuts(
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
                SingleActivator(
                  LogicalKeyboardKey.enter,
                  meta: true,
                ): _CommitIntent(),
                SingleActivator(
                  LogicalKeyboardKey.enter,
                  control: true,
                ): _CommitIntent(),
                // ⌘S / Ctrl+S — standard save shortcut while editing.
                SingleActivator(
                  LogicalKeyboardKey.keyS,
                  meta: true,
                ): _CommitIntent(),
                SingleActivator(
                  LogicalKeyboardKey.keyS,
                  control: true,
                ): _CommitIntent(),
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
                  cursorColor: tokens.colors.interactive.enabled,
                  minLines: 1,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    // Disable every variant so the focused state doesn't
                    // paint a second ring inside the capsule's outer border.
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
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
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TaskShowcasePriorityGlyph(priority: priority),
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

class _ProjectChip extends StatelessWidget {
  const _ProjectChip({required this.project, required this.onTap});

  final DesktopTaskHeaderProject? project;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final hasProject = project != null;
    if (!hasProject) {
      return _PlaceholderChip(
        icon: Icons.folder_outlined,
        label: context.messages.projectPickerUnassigned,
        onTap: onTap,
      );
    }
    final color = TaskShowcasePalette.highText(context);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            project!.icon ?? Icons.folder_outlined,
            size: 12,
            color: TaskShowcasePalette.mediumText(context),
          ),
          SizedBox(width: tokens.spacing.step1),
          Flexible(
            child: Text(
              project!.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.others.caption.copyWith(
                color: color,
                height: 1,
              ),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category, this.onTap});

  final DesktopTaskHeaderCategory category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final content = Container(
      constraints: const BoxConstraints(minHeight: 20),
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
              height: 1,
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
    final color = switch (dueDate.urgency) {
      DesktopTaskHeaderDueUrgency.overdue => TaskShowcasePalette.error(context),
      DesktopTaskHeaderDueUrgency.today => TaskShowcasePalette.warning(context),
      DesktopTaskHeaderDueUrgency.normal => TaskShowcasePalette.lowText(
        context,
      ),
    };
    final content = Container(
      constraints: const BoxConstraints(minHeight: 20),
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
              height: 1,
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

/// Placeholder chip for `No …` empty states (no category, no due date, no
/// labels, no project). Subdued outline + italic label + leading icon.
/// Tapping opens the same picker as the filled variant via [onTap].
class _PlaceholderChip extends StatelessWidget {
  const _PlaceholderChip({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = TaskShowcasePalette.lowText(context);
    final content = Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: tokens.spacing.step1),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
              fontStyle: FontStyle.italic,
              height: 1,
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

/// Hybrid label chip: outlined `radii.xs` shape, caption-sized padding,
/// leading 8px color dot + high-emphasis primary text for legibility.
/// Long-press reveals the label's description in a dialog when set.
class _LabelChip extends StatelessWidget {
  const _LabelChip({required this.label, this.onTap});

  final LabelDefinition label;
  final VoidCallback? onTap;

  bool get _hasDescription {
    final description = label.description?.trim();
    return description != null && description.isNotEmpty;
  }

  Future<void> _showDescription(BuildContext context) async {
    final description = label.description?.trim();
    if (description == null || description.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label.name),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.messages.tasksLabelsDialogClose),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dotColor = colorFromCssHex(
      label.color,
      substitute: TaskShowcasePalette.mediumText(context),
    );
    final content = Container(
      constraints: const BoxConstraints(minHeight: 20),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label.name,
            style: tokens.typography.styles.others.caption.copyWith(
              color: TaskShowcasePalette.highText(context),
              height: 1,
            ),
          ),
        ],
      ),
    );
    final longPress = _hasDescription ? () => _showDescription(context) : null;
    if (onTap == null && longPress == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        onTap: onTap,
        onLongPress: longPress,
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
