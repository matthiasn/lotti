import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_meta.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_title.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

export 'package:lotti/features/tasks/ui/header/desktop_task_header_render.dart';

/// Project reference shown in the breadcrumb. When the task has no project,
/// the connector passes `null` and the crumb renders the literal "No project"
/// placeholder; the same `onProjectTap` callback still fires so users can
/// attach one.
@immutable
class DesktopTaskHeaderProject {
  const DesktopTaskHeaderProject({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Work category surfaced as the colored dot at the start of the breadcrumb
/// and the leading category-name segment.
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

/// Urgency levels for the due-date pill. `today` paints orange; `overdue`
/// paints red; `normal` uses `text.mediumEmphasis` outline.
enum DesktopTaskHeaderDueUrgency { normal, today, overdue }

/// Due-date payload for the metadata row.
@immutable
class DesktopTaskHeaderDueDate {
  const DesktopTaskHeaderDueDate({
    required this.label,
    this.urgency = DesktopTaskHeaderDueUrgency.normal,
  });

  final String label;
  final DesktopTaskHeaderDueUrgency urgency;
}

/// View model passed to the presentational [DesktopTaskHeader]. Built by the
/// Riverpod-aware connector or by fixtures (Widgetbook, tests).
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
  final List<LabelDefinition> labels;
}

/// Presentational task header — Option B layout from
/// `docs/design/design_handoff_task_header/`.
///
/// Two-tier hierarchy:
/// 1. **Crumb** — `▣ Category / Project name` above the title, getting the
///    "where am I?" info out of the chip soup.
/// 2. **Title** — heading-3 with an always-shown small edit pencil to its
///    right; tap toggles the inline editor.
/// 3. **Meta row** — pill chips for the *actionable* metadata (priority, due,
///    estimate, labels) followed by the status select pinned to the right
///    edge of the row.
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
  final VoidCallback? onAddLabelTap;

  /// Slot for the estimate pill. The connector injects a Riverpod-aware chip
  /// here so the header itself stays framework free. When `null` the meta
  /// row simply omits the estimate entry.
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final rowGap = tokens.spacing.step3;
    // Step4 (12) horizontal on mobile leaves a touch-friendly gutter; on
    // desktop the side panels already supply outer chrome so step3 (8) keeps
    // the chip row visually anchored. Top is 0 — the host pane controls
    // the space above the crumb.
    final outerPadding = EdgeInsets.fromLTRB(
      isMobile ? tokens.spacing.step3 : tokens.spacing.step1,
      tokens.spacing.step2,
      isMobile ? tokens.spacing.step3 : tokens.spacing.step1,
      tokens.spacing.step3,
    );

    return Padding(
      padding: outerPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroCrumb(
            category: widget.data.category,
            project: widget.data.project,
            onCategoryTap: widget.onCategoryTap,
            onProjectTap: widget.onProjectTap,
          ),
          SizedBox(height: rowGap),
          _buildTitleLine(context),
          SizedBox(height: rowGap),
          MetaRow(
            priority: widget.data.priority,
            status: widget.data.status,
            dueDate: widget.data.dueDate,
            labels: widget.data.labels,
            estimateSlot: widget.estimateSlot,
            onPriorityTap: widget.onPriorityTap,
            onStatusTap: widget.onStatusTap,
            onDueDateTap: widget.onDueDateTap,
            onLabelTap: widget.onLabelTap,
            onAddLabelTap: widget.onAddLabelTap,
          ),
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
      return TitleEditor(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: style,
        onCommit: _commitEdit,
        onCancel: _cancelEdit,
      );
    }
    return TitleReadOnly(
      title: widget.data.title,
      style: style,
      onTap: _beginEdit,
    );
  }
}

/// Tiny breadcrumb above the title: `▣ Category / Project name`.
///
/// The category color is used as a 10×10 rounded square — this is the *only*
/// place the category color is used as a fill. Text never picks it up.
class _HeroCrumb extends StatelessWidget {
  const _HeroCrumb({
    required this.category,
    required this.project,
    required this.onCategoryTap,
    required this.onProjectTap,
  });

  final DesktopTaskHeaderCategory? category;
  final DesktopTaskHeaderProject? project;
  final VoidCallback? onCategoryTap;
  final VoidCallback? onProjectTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final categoryColor =
        category?.color ?? TaskShowcasePalette.lowText(context);
    final categoryName =
        category?.label ?? context.messages.taskCategoryUnassignedLabel;
    final projectName =
        project?.label ?? context.messages.projectPickerUnassigned;
    final crumbStyle = tokens.typography.styles.others.caption.copyWith(
      height: 1,
    );

    return Row(
      children: [
        // Both segments are flexible so a long user-defined category name
        // shrinks/ellipsizes in proportion with a long project name instead
        // of forcing horizontal overflow on the whole row.
        Flexible(
          child: _CrumbSegment(
            onTap: onCategoryTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                Flexible(
                  child: Text(
                    categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: crumbStyle.copyWith(
                      color: TaskShowcasePalette.highText(context),
                      fontStyle: category == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          '/',
          style: crumbStyle.copyWith(
            color: TaskShowcasePalette.lowText(context),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: _CrumbSegment(
            onTap: onProjectTap,
            child: Text(
              projectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: crumbStyle.copyWith(
                color: TaskShowcasePalette.mediumText(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tappable crumb segment with a subtle hover background. Avoids pill chrome
/// — it's a flat hit target the size of the text.
class _CrumbSegment extends StatelessWidget {
  const _CrumbSegment({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.s);
    final padding = EdgeInsets.symmetric(
      horizontal: tokens.spacing.step2,
      vertical: tokens.spacing.step1,
    );
    if (onTap == null) {
      return Padding(padding: padding, child: child);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
