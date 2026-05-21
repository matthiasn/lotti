import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

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
          _MetaRow(
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

/// Single chip row holding actionable metadata + the right-pinned status
/// pill. On wide viewports the chips wrap on the left and status sits at
/// the far right; below the breakpoint the chips wrap above and status
/// drops to its own right-aligned line.
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.priority,
    required this.status,
    required this.dueDate,
    required this.labels,
    required this.estimateSlot,
    required this.onPriorityTap,
    required this.onStatusTap,
    required this.onDueDateTap,
    required this.onLabelTap,
    required this.onAddLabelTap,
  });

  final TaskPriority priority;
  final TaskStatus status;
  final DesktopTaskHeaderDueDate? dueDate;
  final List<LabelDefinition> labels;
  final Widget? estimateSlot;
  final VoidCallback? onPriorityTap;
  final VoidCallback? onStatusTap;
  final VoidCallback? onDueDateTap;
  final ValueChanged<LabelDefinition>? onLabelTap;
  final VoidCallback? onAddLabelTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final children = <Widget>[
      _PriorityPillTinted(priority: priority, onTap: onPriorityTap),
      _DuePill(dueDate: dueDate, onTap: onDueDateTap),
      ?estimateSlot,
      if (labels.isEmpty)
        DsGhostChip(
          label: context.messages.tasksAddLabelButton,
          onTap: onAddLabelTap,
        )
      else
        for (final label in labels)
          _LabelPill(
            label: label,
            onTap: onLabelTap == null ? null : () => onLabelTap!(label),
          ),
    ];

    return _TrailingAlignedWrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        ...children,
        _StatusPill(status: status, onTap: onStatusTap),
      ],
    );
  }
}

/// Wrap-style horizontal layout where the **last child** is pinned to the
/// right edge of whichever row it lands on. If the trailing child doesn't
/// fit in the same row as the leading chips, it falls onto its own row,
/// still right-aligned.
///
/// Used by the meta row so the status pill always sits at the end of the
/// final visible row, without snapping to a separate column at an arbitrary
/// breakpoint.
class _TrailingAlignedWrap extends MultiChildRenderObjectWidget {
  const _TrailingAlignedWrap({
    required this.spacing,
    required this.runSpacing,
    required super.children,
  });

  final double spacing;
  final double runSpacing;

  @override
  _RenderTrailingAlignedWrap createRenderObject(BuildContext context) {
    return _RenderTrailingAlignedWrap(
      spacing: spacing,
      runSpacing: runSpacing,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderTrailingAlignedWrap renderObject,
  ) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing;
  }
}

class _TrailingAlignedWrapParentData
    extends ContainerBoxParentData<RenderBox> {}

class _RenderTrailingAlignedWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _TrailingAlignedWrapParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _TrailingAlignedWrapParentData
        > {
  _RenderTrailingAlignedWrap({
    required this._spacing,
    required this._runSpacing,
  });

  double _spacing;
  double get spacing => _spacing;
  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double _runSpacing;
  double get runSpacing => _runSpacing;
  set runSpacing(double value) {
    if (_runSpacing == value) return;
    _runSpacing = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(covariant RenderBox child) {
    if (child.parentData is! _TrailingAlignedWrapParentData) {
      child.parentData = _TrailingAlignedWrapParentData();
    }
  }

  // Typed accessor for the parentData. `setupParentData` guarantees every
  // child has been outfitted with our parent-data type by the time layout /
  // intrinsics run, so `parentData!` is sound here. Keeping the bang inside
  // a single helper avoids `cast_nullable_to_non_nullable` warnings at every
  // call site.
  _TrailingAlignedWrapParentData _pd(RenderBox child) =>
      child.parentData! as _TrailingAlignedWrapParentData;

  @override
  void performLayout() {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : double.infinity;

    final boxes = <RenderBox>[];
    var cursor = firstChild;
    while (cursor != null) {
      boxes.add(cursor);
      cursor = _pd(cursor).nextSibling;
    }
    if (boxes.isEmpty) {
      size = constraints.constrain(Size.zero);
      return;
    }

    for (final child in boxes) {
      child.layout(
        BoxConstraints(maxWidth: maxWidth),
        parentUsesSize: true,
      );
    }

    final trailing = boxes.last;
    final leading = boxes.sublist(0, boxes.length - 1);

    // Greedy pack leading children into rows.
    final rowIndex = <int>[];
    final rowWidth = <double>[0];
    final rowHeight = <double>[0];
    var currentRow = 0;
    for (var i = 0; i < leading.length; i++) {
      final w = leading[i].size.width;
      final h = leading[i].size.height;
      final isFirstInRow = rowWidth[currentRow] == 0;
      final candidate = isFirstInRow ? w : rowWidth[currentRow] + _spacing + w;
      if (candidate <= maxWidth || isFirstInRow) {
        rowIndex.add(currentRow);
        rowWidth[currentRow] = candidate;
        rowHeight[currentRow] = math.max(rowHeight[currentRow], h);
      } else {
        currentRow += 1;
        rowWidth.add(w);
        rowHeight.add(h);
        rowIndex.add(currentRow);
      }
    }

    // Place trailing on the last row if it fits, otherwise on a new row.
    final tw = trailing.size.width;
    final th = trailing.size.height;
    final lastRowEmpty = rowWidth[currentRow] == 0;
    final fitsLast = lastRowEmpty
        ? tw <= maxWidth
        : (rowWidth[currentRow] + _spacing + tw) <= maxWidth;
    final int trailingRow;
    if (fitsLast) {
      trailingRow = currentRow;
      rowHeight[currentRow] = math.max(rowHeight[currentRow], th);
    } else {
      trailingRow = currentRow + 1;
      rowWidth.add(tw);
      rowHeight.add(th);
    }

    // Compute row Y origins.
    final rowY = <double>[];
    var y = 0.0;
    for (var r = 0; r < rowHeight.length; r++) {
      rowY.add(y);
      y += rowHeight[r];
      if (r < rowHeight.length - 1) y += _runSpacing;
    }
    final totalHeight = y;

    // Position leading children left-to-right with center vertical alignment.
    final cursorX = List<double>.filled(rowHeight.length, 0);
    for (var i = 0; i < leading.length; i++) {
      final r = rowIndex[i];
      final isFirst = cursorX[r] == 0;
      final x = isFirst ? 0.0 : cursorX[r] + _spacing;
      final h = leading[i].size.height;
      final dy = rowY[r] + (rowHeight[r] - h) / 2;
      _pd(leading[i]).offset = Offset(x, dy);
      cursorX[r] = x + leading[i].size.width;
    }

    // Pin trailing child to the right edge of its row.
    final boundedWidth = maxWidth.isFinite
        ? maxWidth
        : (cursorX[trailingRow] +
              (cursorX[trailingRow] > 0 ? _spacing : 0) +
              tw);
    final tx = boundedWidth - tw;
    final ty = rowY[trailingRow] + (rowHeight[trailingRow] - th) / 2;
    _pd(trailing).offset = Offset(tx, ty);

    size = constraints.constrain(Size(boundedWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    var width = 0.0;
    var c = firstChild;
    while (c != null) {
      width = math.max(width, c.getMinIntrinsicWidth(double.infinity));
      c = _pd(c).nextSibling;
    }
    return width;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    var width = 0.0;
    var c = firstChild;
    while (c != null) {
      width += c.getMaxIntrinsicWidth(double.infinity);
      c = _pd(c).nextSibling;
    }
    return width;
  }

  @override
  double computeMinIntrinsicHeight(double width) =>
      computeMaxIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) {
    var height = 0.0;
    var c = firstChild;
    while (c != null) {
      height = math.max(height, c.getMaxIntrinsicHeight(width));
      c = _pd(c).nextSibling;
    }
    return height;
  }
}

class _PriorityPillTinted extends StatelessWidget {
  const _PriorityPillTinted({required this.priority, this.onTap});

  final TaskPriority priority;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.p0Urgent => TaskShowcasePalette.error(context),
      TaskPriority.p1High => TaskShowcasePalette.warning(context),
      TaskPriority.p2Medium => TaskShowcasePalette.info(context),
      TaskPriority.p3Low => TaskShowcasePalette.success(context),
    };
    return DsPill(
      variant: DsPillVariant.tinted,
      color: color,
      label: priority.short,
      leading: TaskShowcasePriorityGlyph(priority: priority, size: 14),
      onTap: onTap,
    );
  }
}

class _DuePill extends StatelessWidget {
  const _DuePill({required this.dueDate, this.onTap});

  final DesktopTaskHeaderDueDate? dueDate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dueDate = this.dueDate;
    if (dueDate == null) {
      return DsPill(
        variant: DsPillVariant.muted,
        label: context.messages.taskNoDueDateLabel,
        leading: Icon(
          Icons.calendar_today_outlined,
          size: 12,
          color: TaskShowcasePalette.lowText(context),
        ),
        onTap: onTap,
      );
    }
    final color = switch (dueDate.urgency) {
      DesktopTaskHeaderDueUrgency.overdue => TaskShowcasePalette.error(context),
      DesktopTaskHeaderDueUrgency.today => TaskShowcasePalette.warning(context),
      DesktopTaskHeaderDueUrgency.normal => TaskShowcasePalette.mediumText(
        context,
      ),
    };
    return DsPill(
      variant: DsPillVariant.outline,
      color: color,
      label: dueDate.label,
      leading: Icon(Icons.calendar_today_outlined, size: 12, color: color),
      onTap: onTap,
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, this.onTap});

  final TaskStatus status;
  final VoidCallback? onTap;

  static const double _height = 32;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tint = _statusTint(context, status);
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final label = status.localizedLabel(context);
    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: tint.foreground,
      height: 1,
      decoration: status is TaskRejected ? TextDecoration.lineThrough : null,
    );
    final content = SizedBox(
      height: _height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TaskShowcaseStatusGlyph(status: status, size: 14),
            SizedBox(width: tokens.spacing.step2),
            Text(label, style: labelStyle),
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.expand_more_rounded,
              size: 14,
              color: TaskShowcasePalette.lowText(context),
            ),
          ],
        ),
      ),
    );
    final shaped = DecoratedBox(
      decoration: BoxDecoration(
        color: tint.background,
        borderRadius: radius,
      ),
      child: content,
    );
    if (onTap == null) return shaped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: shaped,
      ),
    );
  }
}

class _StatusTint {
  const _StatusTint({required this.background, required this.foreground});

  final Color background;
  final Color foreground;
}

_StatusTint _statusTint(BuildContext context, TaskStatus status) {
  return switch (status) {
    TaskInProgress() => _tintFromAccent(
      TaskShowcasePalette.info(context),
      bgAlpha: 0.18,
    ),
    TaskBlocked() => _tintFromAccent(
      TaskShowcasePalette.error(context),
      bgAlpha: 0.18,
    ),
    TaskOnHold() => _tintFromAccent(
      TaskShowcasePalette.warning(context),
      bgAlpha: 0.18,
    ),
    TaskGroomed() => _tintFromAccent(
      context.designTokens.colors.interactive.enabled,
      bgAlpha: 0.18,
    ),
    TaskDone() => _tintFromAccent(
      TaskShowcasePalette.success(context),
      bgAlpha: 0.18,
    ),
    TaskRejected() => _StatusTint(
      background: TaskShowcasePalette.lowText(
        context,
      ).withValues(alpha: 0.14),
      foreground: TaskShowcasePalette.lowText(context),
    ),
    TaskOpen() => _StatusTint(
      background: TaskShowcasePalette.mediumText(
        context,
      ).withValues(alpha: 0.12),
      foreground: TaskShowcasePalette.highText(context),
    ),
  };
}

_StatusTint _tintFromAccent(Color accent, {required double bgAlpha}) {
  return _StatusTint(
    background: accent.withValues(alpha: bgAlpha),
    foreground: accent,
  );
}

/// 8px circle filled with the label's own color. Used as the leading dot in
/// label pills so the label color stays visible while the chip text remains
/// high-emphasis.
class _LabelDot extends StatelessWidget {
  const _LabelDot({required this.color});

  final String color;

  @override
  Widget build(BuildContext context) {
    final fillColor = colorFromCssHex(
      color,
      substitute: TaskShowcasePalette.mediumText(context),
    );
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Label-specific pill: a filled `DsPill` with the label's color dot, and a
/// long-press dialog showing the label description (when one is set). The
/// long-press affordance was carried over from the previous classification
/// row where label descriptions weren't otherwise reachable.
class _LabelPill extends StatelessWidget {
  const _LabelPill({required this.label, this.onTap});

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
    return DsPill(
      variant: DsPillVariant.filled,
      label: label.name,
      leading: _LabelDot(color: label.color),
      onTap: onTap,
      onLongPress: _hasDescription ? () => _showDescription(context) : null,
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
    final tokens = context.designTokens;
    final isEmpty = title.trim().isEmpty;
    final displayText = isEmpty ? context.messages.taskTitleEmpty : title;
    final effectiveStyle = isEmpty
        ? style.copyWith(
            color: TaskShowcasePalette.mediumText(context),
            fontStyle: FontStyle.italic,
          )
        : style;
    return Semantics(
      label: context.messages.taskEditTitleLabel,
      button: true,
      container: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onTap();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  displayText,
                  softWrap: true,
                  style: effectiveStyle,
                ),
              ),
              SizedBox(width: tokens.spacing.step2),
              Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step1),
                child: Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: TaskShowcasePalette.lowText(context),
                ),
              ),
            ],
          ),
        ),
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
