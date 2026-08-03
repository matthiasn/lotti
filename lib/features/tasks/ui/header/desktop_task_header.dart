import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_meta.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header_title.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Project reference shown in the breadcrumb. When the task has a category but
/// no project, the connector passes `null` and the crumb renders the literal
/// "No project" placeholder; the same `onProjectTap` callback still fires so
/// users can attach one. Without a category that placeholder is dropped, since
/// no project can be picked yet — a project that *is* linked always shows. See
/// [_HeroCrumb].
@immutable
class DesktopTaskHeaderProject {
  const DesktopTaskHeaderProject({required this.label});

  final String label;
}

/// Work category surfaced as the colored dot at the start of the breadcrumb
/// and the leading category-name segment.
@immutable
class DesktopTaskHeaderCategory {
  const DesktopTaskHeaderCategory({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
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
    this.consumptionSlot,
    this.blockedBySlot,
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

  /// Optional AI-consumption pill forwarded into [MetaRow].
  final Widget? consumptionSlot;

  /// Optional "Blocked by" chip forwarded into [MetaRow].
  final Widget? blockedBySlot;

  /// Force the inline editor open on first build.
  ///
  /// The connector passes `true` for a task whose title is still blank, so a
  /// freshly created task lands with the cursor in the field. Widgetbook and
  /// tests also use it to pin the editing state without simulating a tap.
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
    // Losing focus resolves the editor back to the read-only title. Without
    // this the editor stayed open forever once auto-opened: tapping anywhere
    // else dismissed the keyboard but left the field, its border and its
    // buttons on screen, so "edit mode" had exactly one exit — the ✕ users
    // were most afraid to press.
    _titleFocusNode.addListener(_onFocusChanged);
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocusNode.requestFocus();
      });
    }
  }

  void _onFocusChanged() {
    if (_titleFocusNode.hasFocus || !_isEditing || !mounted) return;
    // Deferred by a frame, and re-checked. A tap on the editor's own ✕ first
    // takes focus away from the field and only then runs the cancel handler —
    // committing synchronously here would save the very text the user asked
    // to discard. By the next frame `_cancelEdit` has cleared `_isEditing`
    // and this backs off.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isEditing || _titleFocusNode.hasFocus) return;
      // Commit rather than discard: the text is in front of the user, they
      // typed it, and throwing it away because they tapped elsewhere is the
      // more surprising of the two outcomes. `_commitEdit` already no-ops on
      // an empty or unchanged value.
      _commitEdit();
    });
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
    _titleFocusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
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
    // Proximity grouping: the breadcrumb is a separate ancestor-context unit,
    // so it sits a full step (step4) above the title; the title then bonds
    // DOWN to its own metadata with a tighter step (step3), matching the
    // lane-to-lane gap inside the metadata block — so title + chips read as
    // one identity unit rather than the title floating up toward the crumb.
    final crumbGap = tokens.spacing.step4;
    final metaGap = tokens.spacing.step3;
    // No horizontal inset: the page owns the content gutter (see
    // `TaskDetailsPage`'s sliver padding) so the crumb, the title and the
    // chips share one left rail with everything below them. The header used
    // to add its own step3/step1 on top of the page's, which is how the top
    // of the page ended up with five different left edges.
    final outerPadding = EdgeInsets.only(
      top: tokens.spacing.step2,
      // step2, not step3: whatever section follows brings its own leading
      // padding (LinkedTasks and the checklists card both add step3), so a
      // step3 here stacked into a gap wider than the one separating the
      // header's own internal tiers — the metadata block floated free of the
      // title it belongs to and bonded to the card below instead.
      bottom: tokens.spacing.step2,
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
          SizedBox(height: crumbGap),
          _buildTitleLine(context),
          SizedBox(height: metaGap),
          MetaRow(
            priority: widget.data.priority,
            status: widget.data.status,
            dueDate: widget.data.dueDate,
            labels: widget.data.labels,
            estimateSlot: widget.estimateSlot,
            consumptionSlot: widget.consumptionSlot,
            blockedBySlot: widget.blockedBySlot,
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
    // The task title is the page's primary focal point, so it sits a clear
    // step above the card/section headers (subtitle2) rather than one notch
    // up — heading2 gives an unambiguous title → section → body cascade.
    // A slightly looser line-height keeps a multi-line wrapping title reading
    // as one cohesive block rather than two stacked lines.
    final style = tokens.typography.styles.heading.heading2.copyWith(
      color: TaskShowcasePalette.highText(context),
      height: 1.15,
    );
    // The title spans the full content width and wraps freely; the status
    // control no longer rides this line, so a long title never leaves a void
    // beside a marooned pill (it leads the metadata block below instead).
    if (_isEditing) {
      return TitleEditor(
        controller: _titleController,
        focusNode: _titleFocusNode,
        style: style,
        originalTitle: widget.data.title,
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
///
/// **The project *placeholder* is conditional on the category.** A project is
/// picked within a category — `linkTaskToProject` rejects cross-category links
/// and the connector passes a null `onProjectTap` without one — so
/// `No category / No project` offered a separator and a placeholder for a
/// choice that cannot be made yet.
///
/// A project that is actually linked is always shown, category or not. An
/// uncategorized project is a real thing (`createProject` takes a nullable
/// category), and `createTask(projectId:)` copies the project's category onto
/// the new task — `null` included — so a task legitimately reaches this widget
/// with no category and a project. Gating on the category alone would hide
/// membership the user has.
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
    // "No category" rather than a bare "unassigned": the crumb names two
    // different things side by side, so the placeholder has to say which one
    // is missing — and it is sentence-cased like the "No project" it sits next
    // to instead of mismatching it in lowercase.
    final categoryName =
        category?.label ?? context.messages.taskHeaderNoCategoryLabel;
    final projectName =
        project?.label ?? context.messages.projectPickerUnassigned;
    // The breadcrumb is an "eyebrow": a quiet, slightly tracked caption that
    // reads as ancestor context one tier *below* the metadata chips, so it
    // never competes with them for attention.
    final crumbStyle = tokens.typography.styles.others.caption.copyWith(
      height: 1,
      letterSpacing: 0.4,
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
                // Filled when the task HAS a category; a hollow ring when it
                // does not. A solid grey square asserted a colour the task
                // never had, and it was the loudest mark in an otherwise quiet
                // breadcrumb — the first ink on the page standing for an
                // absence.
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: category == null ? null : categoryColor,
                    border: category == null
                        ? Border.all(color: tokens.colors.decorative.level02)
                        : null,
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
                      // The breadcrumb is quiet ancestor context, so even a
                      // set category sits at medium (not high) emphasis — a
                      // tier below the metadata chips, and comfortably legible
                      // (~7:1). An unset one no longer adds italics: the page
                      // already signals "empty" on the dashed chips below, and
                      // slanting a 12pt caption for it cost legibility without
                      // adding meaning.
                      color: TaskShowcasePalette.mediumText(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (category != null || project != null) ...[
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
                  // Keep an unset project legible (medium emphasis) for
                  // low-vision users rather than fading it to near-invisible.
                  color: TaskShowcasePalette.mediumText(context),
                ),
              ),
            ),
          ),
        ],
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
    // Vertical only. A horizontal inset here pushed the category dot — the
    // page's first ink — inside the rail every other element starts on, so
    // the breadcrumb read as indented from the title above nothing.
    final padding = EdgeInsets.symmetric(vertical: tokens.spacing.step1);
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
