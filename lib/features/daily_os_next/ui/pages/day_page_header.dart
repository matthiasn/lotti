// The day header and its single-line measurement machinery (a custom
// multi-child render object that decides whether the plan toggle fits
// inline). Split out of the day_page library; day_page imports this.
import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/ui/agent_surface_menu.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_agent_status_chip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_week_strip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_nudge.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/plan_view_toggle.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/processing_category_filter_button.dart';
import 'package:lotti/features/daily_os_next/util/day_arithmetic.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// How the day page moves between days. The route-level root supplies it;
/// without it the page shows its date with a back chevron and no week strip.
@immutable
class DayNavigation {
  const DayNavigation({
    required this.today,
    required this.onSelect,
    required this.onPick,
    required this.onToday,
  });

  /// The current day, for the masthead's overline and the strip's dot.
  final DateTime today;

  /// Shows another day — a tapped cell, or the selection moved a week.
  final ValueChanged<DateTime> onSelect;

  /// Opens the date picker (a tap on the masthead).
  final VoidCallback onPick;

  /// Returns to today (a long press on the masthead).
  final VoidCallback onToday;
}

class DayHeader extends StatelessWidget {
  const DayHeader({
    required this.navigation,
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

  /// Day navigation, when the page is the routed surface. With it the
  /// masthead opens the picker and the week strip sits under it; without it
  /// a back chevron leads the header instead.
  final DayNavigation? navigation;

  /// The day the page shows: the masthead's title and overline.
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
        verticalPadding: tokens.spacing.step3,
        itemGap: tokens.spacing.step3,
        rowGap: tokens.spacing.step3,
        back: navigation != null
            ? const SizedBox.shrink()
            : IconButton(
                icon: const Icon(LottiIcons.back, size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip: context.messages.dailyOsNextDayBack,
                onPressed: onBack,
              ),
        title: _DayMasthead(
          date: date,
          today: navigation?.today ?? clock.now(),
          onPick: navigation?.onPick,
          onToday: navigation?.onToday,
        ),
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
            // The way back to today, in sight whenever the page is on
            // another day (the masthead's long press does the same).
            if (navigation case final navigation?
                when !DateUtils.isSameDay(date, navigation.today))
              Padding(
                padding: EdgeInsets.only(right: tokens.spacing.step2),
                child: DesignSystemButton(
                  key: const Key('daily_os_day_today'),
                  label: context.messages.dailyOsTodayButton,
                  leadingIcon: LottiIcons.today,
                  variant: DesignSystemButtonVariant.outlined,
                  size: DesignSystemButtonSize.dense,
                  tapTargetSize: MaterialTapTargetSize.padded,
                  onPressed: navigation.onToday,
                ),
              ),
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
            AgentSurfaceMenuButton(
              semanticsLabel: context.messages.dailyOsNextDayMoreTooltip,
              items: [
                if (onSettings != null)
                  DesignSystemContextMenuItem(
                    icon: LottiIcons.settings,
                    label: context.messages.dailyOsNextDayMenuSettings,
                    onTap: onSettings,
                  ),
                DesignSystemContextMenuItem(
                  icon: LottiIcons.reasoning,
                  label: context.messages.dailyOsNextDayMenuInspectAgent,
                  onTap: onInspectAgent,
                ),
                DesignSystemContextMenuItem(
                  icon: LottiIcons.aiSpark,
                  label: context.messages.agentKnowledgeTitle,
                  onTap: () => unawaited(showKnowledgePanelModal(context)),
                ),
                if (hasPlan)
                  DesignSystemContextMenuItem(
                    icon: LottiIcons.delete,
                    label: context.messages.dailyOsNextDayMenuDeletePlan,
                    isDestructive: true,
                    startsGroup: true,
                    onTap: onDeletePlan,
                  ),
              ],
              triggerBuilder: (context, open) => IconButton(
                tooltip: context.messages.dailyOsNextDayMoreTooltip,
                onPressed: open,
                icon: const Icon(LottiIcons.moreVertical),
              ),
            ),
          ],
        ),
        weekStrip: switch (navigation) {
          null => const SizedBox.shrink(),
          final navigation => Padding(
            padding: EdgeInsets.only(left: tokens.spacing.step3),
            child: DayWeekStrip(
              selected: date,
              today: navigation.today,
              onSelect: navigation.onSelect,
              showWeekChevrons: isDesktopLayout(context),
            ),
          ),
        },
      ),
    );
  }
}

/// The date as the page's title: an overline saying how the day relates to
/// today ("Today · Sunday", "Tomorrow · Monday"; another day's weekday, with
/// its year when that is not this year's) over the month and day in
/// heading2. Tabular figures keep the title from reflowing between days.
///
/// With [onPick] the title is a button that opens the date picker, and a
/// long press runs [onToday].
class _DayMasthead extends StatelessWidget {
  const _DayMasthead({
    required this.date,
    required this.today,
    this.onPick,
    this.onToday,
  });

  final DateTime date;
  final DateTime today;
  final VoidCallback? onPick;
  final VoidCallback? onToday;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final locale = Localizations.localeOf(context).toString();
    final weekday = DateFormat.EEEE(locale).format(date);
    final relation = switch (daysBetween(today, date)) {
      0 => messages.dailyOsNextDayRelationToday,
      1 => messages.dailyOsNextDayRelationTomorrow,
      -1 => messages.dailyOsNextDayRelationYesterday,
      _ => null,
    };
    final overline = relation != null
        ? messages.dailyOsNextDayOverline(relation, weekday)
        : date.year != today.year
        ? messages.dailyOsNextDayOverline(
            weekday,
            DateFormat.y(locale).format(date),
          )
        : weekday;
    const tabular = [FontFeature.tabularFigures()];
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: calmEyebrowStyle(tokens).copyWith(fontFeatures: tabular),
        ),
        SizedBox(height: tokens.spacing.step1),
        Text(
          DateFormat.MMMMd(locale).format(date),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tokens.typography.styles.heading.heading2.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontFeatures: tabular,
          ),
        ),
      ],
    );
    // Apple large-title anatomy: the title sits on the page's left rail
    // (header padding step3 + step3 lead = step5, same as content).
    final onPick = this.onPick;
    return Padding(
      padding: EdgeInsets.only(left: tokens.spacing.step3),
      child: onPick == null
          ? column
          : InkWell(
              key: const Key('daily_os_day_masthead'),
              onTap: onPick,
              onLongPress: onToday,
              borderRadius: BorderRadius.circular(tokens.radii.m),
              child: column,
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
    required Widget weekStrip,
    required this.horizontalPadding,
    required this.endInset,
    required this.verticalPadding,
    required this.itemGap,
    required this.rowGap,
  }) : super(children: [back, title, toggle, actions, weekStrip]);

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

  RenderBox get _weekStrip {
    final child = childAfter(_actions);
    assert(child != null, 'Measured header week strip child is missing.');
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
    final weekStrip = _weekStrip;
    for (final child in [back, title, toggle, actions, weekStrip]) {
      child.layout(looseContentConstraints, parentUsesSize: true);
    }
    final hasBack = back.size.width > 0;
    final hasWeekStrip = weekStrip.size.width > 0;

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
    // actions across from it, so the masthead and the toggle make the row
    // beneath.
    var actionsPlaced = false;
    if (hasBack) {
      final nav = _HeaderRow()..start.add(back);
      rows.add(nav);
      if (fits(nav, actions)) {
        nav.end.add(actions);
        actionsPlaced = true;
      }
    }
    // The masthead leads its row and never gives up width to sit beside the
    // actions, which is what pressed the date into an ellipsis on a phone.
    // The toggle joins it only when the actions, if still to place, fit
    // there too; the actions then take the masthead row's end when they
    // fit beside it.
    final titleRow = _HeaderRow()..start.add(title);
    rows.add(titleRow);
    final pendingWidth = actionsPlaced ? 0 : itemGap + actions.size.width;
    final toggleOnTitleRow =
        titleRow.width(itemGap) + itemGap + toggle.size.width + pendingWidth <=
        contentWidth - endInset;
    if (toggleOnTitleRow) titleRow.start.add(toggle);
    if (!actionsPlaced && fits(titleRow, actions)) {
      titleRow.end.add(actions);
      actionsPlaced = true;
    }
    // The week strip always takes a row of its own, under the masthead it
    // navigates; a toggle that did not fit the masthead's row follows it,
    // with any actions still to place after the toggle.
    if (hasWeekStrip) rows.add(_HeaderRow()..start.add(weekStrip));
    if (!toggleOnTitleRow) rows.add(_HeaderRow()..start.add(toggle));
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
