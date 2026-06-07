// The day header and its single-line measurement machinery (a custom
// multi-child render object that decides whether the plan toggle fits
// inline) — part of the day_page library.
part of 'day_page.dart';

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.dateStrip,
    required this.selectedView,
    required this.hasPlan,
    required this.onViewChanged,
    required this.onBack,
    required this.onInspectAgent,
    required this.onDeletePlan,
  });

  final Widget? dateStrip;
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
        horizontalPadding: tokens.spacing.step5,
        verticalPadding: tokens.spacing.step2,
        itemGap: tokens.spacing.step3,
        rowGap: tokens.spacing.step2,
        title: dateStrip ?? _DefaultDayHeaderTitle(onBack: onBack),
        toggle: PlanViewToggle(
          selected: selectedView,
          onChanged: onViewChanged,
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
  const _DefaultDayHeaderTitle({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: onBack,
        ),
        Flexible(
          child: Text(
            context.messages.dailyOsNextDayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
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
        Offset(
          width - horizontalPadding - actionsSize.width,
          verticalPadding + (rowHeight - actionsSize.height) / 2,
        ),
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
      Offset(
        width - horizontalPadding - actionsSize.width,
        verticalPadding + (firstRowHeight - actionsSize.height) / 2,
      ),
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
