// The day header and its single-line measurement machinery (a custom
// multi-child render object that decides whether the plan toggle fits
// inline). Split out of the day_page library; day_page imports this.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_nudge.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

enum _DayMenuAction { inspectAgent, knowledge, deletePlan }

class DayHeader extends StatelessWidget {
  const DayHeader({
    required this.dateStrip,
    required this.date,
    required this.selectedView,
    required this.hasPlan,
    required this.onViewChanged,
    required this.onBack,
    required this.onInspectAgent,
    required this.onDeletePlan,
    super.key,
  });

  final Widget? dateStrip;

  /// The day shown under the default title as a date overline
  /// ("Thursday, June 11").
  final DateTime date;

  final PlanView selectedView;
  final bool hasPlan;
  final ValueChanged<PlanView> onViewChanged;
  final VoidCallback onBack;
  final VoidCallback onInspectAgent;
  final VoidCallback onDeletePlan;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: tokens.colors.background.level01,
      child: _MeasuredDayHeader(
        // step3 chrome padding + step2 internal lead-ins put the title,
        // the toggle, and the content below on ONE left rail (step5);
        // the back chevron hangs in the gutter left of it.
        horizontalPadding: tokens.spacing.step3,
        verticalPadding: tokens.spacing.step2,
        itemGap: tokens.spacing.step3,
        rowGap: tokens.spacing.step2,
        title: dateStrip ?? _DefaultDayHeaderTitle(onBack: onBack, date: date),
        toggle: Padding(
          padding: EdgeInsets.only(left: tokens.spacing.step2),
          child: PlanViewToggle(
            selected: selectedView,
            onChanged: onViewChanged,
          ),
        ),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProcessingCategoryFilterButton(),
            PopupMenuButton<_DayMenuAction>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: context.messages.dailyOsNextDayMoreTooltip,
              onSelected: (action) {
                switch (action) {
                  case _DayMenuAction.inspectAgent:
                    onInspectAgent();
                  case _DayMenuAction.knowledge:
                    unawaited(showKnowledgePanelModal(context));
                  case _DayMenuAction.deletePlan:
                    onDeletePlan();
                }
              },
              itemBuilder: (popupContext) => [
                PopupMenuItem<_DayMenuAction>(
                  value: _DayMenuAction.inspectAgent,
                  child: ListTile(
                    leading: const Icon(Icons.psychology_alt_outlined),
                    title: Text(
                      popupContext.messages.dailyOsNextDayMenuInspectAgent,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<_DayMenuAction>(
                  value: _DayMenuAction.knowledge,
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome_outlined),
                    title: Text(
                      popupContext.messages.dailyOsNextKnowledgeTitle,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (hasPlan)
                  PopupMenuItem<_DayMenuAction>(
                    value: _DayMenuAction.deletePlan,
                    child: ListTile(
                      leading: const Icon(Icons.delete_outline_rounded),
                      title: Text(
                        popupContext.messages.dailyOsNextDayMenuDeletePlan,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
        ),
      ),
    );
  }
}

class _DefaultDayHeaderTitle extends StatelessWidget {
  const _DefaultDayHeaderTitle({required this.onBack, required this.date});

  final VoidCallback onBack;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    // Apple large-title anatomy: the chevron rides its own quiet line in
    // the gutter; the title and its date overline sit on the page's left
    // rail (header padding step3 + step2 lead = step5, same as content).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: onBack,
        ),
        Padding(
          padding: EdgeInsets.only(left: tokens.spacing.step2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.messages.dailyOsNextDayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: calmPageTitleStyle(tokens),
              ),
              SizedBox(height: tokens.spacing.step1),
              Text(
                DateFormat.MMMMEEEEd(locale).format(date),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: calmEyebrowStyle(tokens),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }
}

class _MeasuredDayHeader extends MultiChildRenderObjectWidget {
  _MeasuredDayHeader({
    required Widget title,
    required Widget toggle,
    required Widget actions,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  }) : super(children: [title, toggle, actions]);

  final double horizontalPadding;
  final double verticalPadding;
  final double itemGap;
  final double rowGap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasuredDayHeader(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      itemGap: itemGap,
      rowGap: rowGap,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMeasuredDayHeader renderObject,
  ) {
    renderObject.updateMetrics(
      horizontalPadding: horizontalPadding,
      verticalPadding: verticalPadding,
      itemGap: itemGap,
      rowGap: rowGap,
    );
  }
}

class _RenderMeasuredDayHeader extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MeasuredDayHeaderParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _MeasuredDayHeaderParentData
        > {
  _RenderMeasuredDayHeader({
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  });

  double horizontalPadding;
  double verticalPadding;
  double itemGap;
  double rowGap;

  void updateMetrics({
    required double horizontalPadding,
    required double verticalPadding,
    required double itemGap,
    required double rowGap,
  }) {
    final changed =
        this.horizontalPadding != horizontalPadding ||
        this.verticalPadding != verticalPadding ||
        this.itemGap != itemGap ||
        this.rowGap != rowGap;
    if (!changed) return;
    this
      ..horizontalPadding = horizontalPadding
      ..verticalPadding = verticalPadding
      ..itemGap = itemGap
      ..rowGap = rowGap;
    markNeedsLayout();
  }

  RenderBox get _title {
    final child = firstChild;
    assert(child != null, 'Measured header title child is missing.');
    return child!;
  }

  RenderBox get _toggle {
    final child = childAfter(_title);
    assert(child != null, 'Measured header toggle child is missing.');
    return child!;
  }

  RenderBox get _actions {
    final child = childAfter(_toggle);
    assert(child != null, 'Measured header actions child is missing.');
    return child!;
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MeasuredDayHeaderParentData) {
      child.parentData = _MeasuredDayHeaderParentData();
    }
  }

  @override
  void performLayout() {
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : constraints.minWidth; // coverage:ignore-line
    final contentWidth = math.max<double>(0, width - horizontalPadding * 2);
    // coverage:ignore-start
    final maxChildHeight = constraints.hasBoundedHeight
        ? constraints.maxHeight
        : double.infinity;
    // coverage:ignore-end
    final looseContentConstraints = BoxConstraints.loose(
      Size(contentWidth, maxChildHeight),
    );

    final title = _title;
    final toggle = _toggle;
    final actions = _actions;

    final actionsSize =
        (actions..layout(looseContentConstraints, parentUsesSize: true)).size;
    final toggleSize =
        (toggle..layout(looseContentConstraints, parentUsesSize: true)).size;
    var titleSize =
        (title..layout(looseContentConstraints, parentUsesSize: true)).size;

    final inlineWidth =
        titleSize.width +
        itemGap +
        toggleSize.width +
        itemGap +
        actionsSize.width;
    final fitsInline = inlineWidth <= contentWidth;

    if (!fitsInline) {
      final titleWidth = math.max<double>(
        0,
        contentWidth - actionsSize.width - itemGap,
      );
      title.layout(
        BoxConstraints.loose(Size(titleWidth, maxChildHeight)),
        parentUsesSize: true,
      );
      titleSize = title.size;
    }

    final firstRowHeight = math.max(titleSize.height, actionsSize.height);
    final headerHeight = fitsInline
        ? verticalPadding * 2 + math.max(firstRowHeight, toggleSize.height)
        : verticalPadding * 2 + firstRowHeight + rowGap + toggleSize.height;

    size = constraints.constrain(Size(width, headerHeight));

    // A multi-line title block (chevron line + title + date) reads as a
    // masthead: actions belong on its FIRST line, not centered against
    // the whole block.
    final actionsY = titleSize.height > actionsSize.height
        ? verticalPadding
        : verticalPadding + (firstRowHeight - actionsSize.height) / 2;

    if (fitsInline) {
      final rowHeight = math.max(firstRowHeight, toggleSize.height);
      _position(
        title,
        Offset(
          horizontalPadding,
          verticalPadding + (rowHeight - titleSize.height) / 2,
        ),
      );
      _position(
        toggle,
        Offset(
          horizontalPadding + titleSize.width + itemGap,
          verticalPadding + (rowHeight - toggleSize.height) / 2,
        ),
      );
      _position(
        actions,
        Offset(width - horizontalPadding - actionsSize.width, actionsY),
      );
      return;
    }

    _position(
      title,
      Offset(
        horizontalPadding,
        verticalPadding + (firstRowHeight - titleSize.height) / 2,
      ),
    );
    _position(
      actions,
      Offset(width - horizontalPadding - actionsSize.width, actionsY),
    );
    _position(
      toggle,
      Offset(horizontalPadding, verticalPadding + firstRowHeight + rowGap),
    );
  }

  void _position(RenderBox child, Offset offset) {
    (child.parentData! as _MeasuredDayHeaderParentData).offset = offset;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

class _MeasuredDayHeaderParentData extends ContainerBoxParentData<RenderBox> {}
