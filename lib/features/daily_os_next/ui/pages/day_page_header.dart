// The day header and its single-line measurement machinery (a custom
// multi-child render object that decides whether the plan toggle fits
// inline). Split out of the day_page library; day_page imports this.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agent_status_chip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_nudge.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

enum _DayMenuAction { settings, inspectAgent, knowledge, deletePlan }

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
    this.onSettings,
    this.companion,
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
  final VoidCallback? onSettings;
  final VoidCallback onDeletePlan;

  /// The companion who briefs the day, leading the actions; it takes no room
  /// when she is off.
  final Widget? companion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: tokens.colors.background.level01,
      child: _MeasuredDayHeader(
        // step3 chrome padding + step3 lead-ins put the title, the toggle,
        // and the content below on ONE left rail (step5); the back chevron
        // hangs in the gutter left of it. The end inset does the same on
        // the right, so the menu lines up with the timeline toolbar.
        horizontalPadding: tokens.spacing.step3,
        endInset: tokens.spacing.step3,
        verticalPadding: tokens.spacing.step2,
        itemGap: tokens.spacing.step3,
        rowGap: tokens.spacing.step2,
        back: dateStrip != null
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(LottiIcons.back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: context.messages.dailyOsNextDayBack,
                onPressed: onBack,
              ),
        title: dateStrip ?? _DefaultDayHeaderTitle(date: date),
        toggle: Padding(
          padding: EdgeInsets.only(left: tokens.spacing.step3),
          child: PlanViewToggle(
            selected: selectedView,
            onChanged: onViewChanged,
          ),
        ),
        actions: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?companion,
            // ADR 0032 phase 4: the day agent's observable state (working /
            // attention / day-closed), tappable straight into its internals.
            // Flexible so the pill's label is what yields at large text
            // sizes — the icon buttons beside it have no slack, so an
            // unconstrained pill overflows the row instead.
            Flexible(
              child: DayAgentStatusChip(
                date: date,
                onInspectAgent: onInspectAgent,
              ),
            ),
            const ProcessingCategoryFilterButton(),
            PopupMenuButton<_DayMenuAction>(
              icon: const Icon(LottiIcons.moreVertical),
              tooltip: context.messages.dailyOsNextDayMoreTooltip,
              onSelected: (action) {
                switch (action) {
                  case _DayMenuAction.settings:
                    onSettings?.call();
                  case _DayMenuAction.inspectAgent:
                    onInspectAgent();
                  case _DayMenuAction.knowledge:
                    unawaited(showKnowledgePanelModal(context));
                  case _DayMenuAction.deletePlan:
                    onDeletePlan();
                }
              },
              itemBuilder: (popupContext) => [
                if (onSettings != null)
                  PopupMenuItem<_DayMenuAction>(
                    value: _DayMenuAction.settings,
                    child: ListTile(
                      leading: const Icon(LottiIcons.settings),
                      title: Text(
                        popupContext.messages.dailyOsNextDayMenuSettings,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                PopupMenuItem<_DayMenuAction>(
                  value: _DayMenuAction.inspectAgent,
                  child: ListTile(
                    leading: const Icon(LottiIcons.reasoning),
                    title: Text(
                      popupContext.messages.dailyOsNextDayMenuInspectAgent,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem<_DayMenuAction>(
                  value: _DayMenuAction.knowledge,
                  child: ListTile(
                    leading: const Icon(LottiIcons.aiSpark),
                    title: Text(
                      popupContext.messages.agentKnowledgeTitle,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (hasPlan)
                  PopupMenuItem<_DayMenuAction>(
                    value: _DayMenuAction.deletePlan,
                    child: ListTile(
                      leading: const Icon(LottiIcons.delete),
                      title: Text(
                        popupContext.messages.dailyOsNextDayMenuDeletePlan,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultDayHeaderTitle extends StatelessWidget {
  const _DefaultDayHeaderTitle({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    // Apple large-title anatomy: the chevron rides the nav row above in the
    // gutter; the title and its date overline sit on the page's left rail
    // (header padding step3 + step3 lead = step5, same as content).
    return Padding(
      padding: EdgeInsets.only(left: tokens.spacing.step3),
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
    );
  }
}

class _MeasuredDayHeader extends MultiChildRenderObjectWidget {
  _MeasuredDayHeader({
    required Widget back,
    required Widget title,
    required Widget toggle,
    required Widget actions,
    required this.horizontalPadding,
    required this.endInset,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  }) : super(children: [back, title, toggle, actions]);

  final double horizontalPadding;

  /// Extra inset of the right-aligned items, beyond [horizontalPadding].
  final double endInset;
  final double verticalPadding;
  final double itemGap;
  final double rowGap;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderMeasuredDayHeader(
      horizontalPadding: horizontalPadding,
      endInset: endInset,
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
      endInset: endInset,
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
    required this.endInset,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  });

  double horizontalPadding;
  double endInset;
  double verticalPadding;
  double itemGap;
  double rowGap;

  void updateMetrics({
    required double horizontalPadding,
    required double endInset,
    required double verticalPadding,
    required double itemGap,
    required double rowGap,
  }) {
    final changed =
        this.horizontalPadding != horizontalPadding ||
        this.endInset != endInset ||
        this.verticalPadding != verticalPadding ||
        this.itemGap != itemGap ||
        this.rowGap != rowGap;
    if (!changed) return;
    this
      ..horizontalPadding = horizontalPadding
      ..endInset = endInset
      ..verticalPadding = verticalPadding
      ..itemGap = itemGap
      ..rowGap = rowGap;
    markNeedsLayout();
  }

  RenderBox get _back {
    final child = firstChild;
    assert(child != null, 'Measured header back child is missing.');
    return child!;
  }

  RenderBox get _title {
    final child = childAfter(_back);
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

    final back = _back;
    final title = _title;
    final toggle = _toggle;
    final actions = _actions;
    for (final child in [back, title, toggle, actions]) {
      child.layout(looseContentConstraints, parentUsesSize: true);
    }
    final hasBack = back.size.width > 0;

    // Rows on two rails: items added to a row's start hold the left rail,
    // items added to its end are right-aligned in order, and every item sits
    // on its row's centre line. An item joins the current row only when the
    // room left covers its measured width — the segmented toggle
    // shrink-wraps to a minimum, so squeezing it overflows and paints over
    // its neighbours — and otherwise starts a row of its own.
    final rows = <_HeaderRow>[];
    bool fits(_HeaderRow row, RenderBox item) =>
        row.width(itemGap) + itemGap + item.size.width <=
        contentWidth - endInset;
    void addEnd(RenderBox item) {
      if (rows.isEmpty || !fits(rows.last, item)) rows.add(_HeaderRow());
      rows.last.end.add(item);
    }

    // A nav row, when there is a chevron: it sits in the gutter and the
    // actions across from it, so the large title and the toggle make the
    // row beneath.
    var actionsPlaced = false;
    if (hasBack) {
      final nav = _HeaderRow()..start.add(back);
      rows.add(nav);
      if (fits(nav, actions)) {
        nav.end.add(actions);
        actionsPlaced = true;
      }
    }
    // Day navigation leads its row; it never gives up width to sit beside
    // the actions, which is what pressed the date into an ellipsis on a
    // phone. The toggle joins it only when the actions, if still to place,
    // fit there too; otherwise the toggle leads the next row and the actions
    // follow it, rather than being stranded on a row of their own.
    final titleRow = _HeaderRow()..start.add(title);
    rows.add(titleRow);
    final pendingWidth = actionsPlaced ? 0 : itemGap + actions.size.width;
    if (titleRow.width(itemGap) + itemGap + toggle.size.width + pendingWidth <=
        contentWidth - endInset) {
      titleRow.start.add(toggle);
    } else {
      rows.add(_HeaderRow()..start.add(toggle));
    }
    if (!actionsPlaced) addEnd(actions);

    final rowHeights = [for (final row in rows) row.height];
    size = constraints.constrain(
      Size(
        width,
        verticalPadding * 2 + rowHeights.reduce((a, b) => a + rowGap + b),
      ),
    );

    var rowTop = verticalPadding;
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final rowHeight = rowHeights[index];
      double centred(RenderBox child) =>
          rowTop + (rowHeight - child.size.height) / 2;
      var left = horizontalPadding;
      for (final child in row.start) {
        _position(child, Offset(left, centred(child)));
        left += child.size.width + itemGap;
      }
      var right = width - horizontalPadding - endInset;
      for (final child in row.end.reversed) {
        right -= child.size.width;
        _position(child, Offset(right, centred(child)));
        right -= itemGap;
      }
      rowTop += rowHeight + rowGap;
    }
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

/// One row of the measured header: [start] items from the left rail,
/// [end] items right-aligned in order.
class _HeaderRow {
  final start = <RenderBox>[];
  final end = <RenderBox>[];

  Iterable<RenderBox> get _all => [...start, ...end];

  double width(double gap) {
    final items = _all.toList();
    if (items.isEmpty) return -gap;
    return items.fold<double>(0, (sum, child) => sum + child.size.width) +
        gap * (items.length - 1);
  }

  double get height => _all.fold<double>(
    0,
    (tallest, child) => math.max(tallest, child.size.height),
  );
}
