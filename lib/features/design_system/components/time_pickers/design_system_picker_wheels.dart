import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Token-backed time-of-day wheel shared by date/time modals.
///
/// It keeps the platform wheel interaction while standardizing value type,
/// row geometry, selected-row color, and settled-change reporting.
class DesignSystemTimeWheel extends StatefulWidget {
  const DesignSystemTimeWheel({
    required this.initialDateTime,
    required this.onDateTimeChanged,
    this.semanticsLabel,
    this.semanticsLiveRegion = false,
    this.use24hFormat = false,
    super.key,
  });

  final DateTime initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;
  final String? semanticsLabel;
  final bool semanticsLiveRegion;
  final bool use24hFormat;

  @override
  State<DesignSystemTimeWheel> createState() => _DesignSystemTimeWheelState();
}

class _DesignSystemTimeWheelState extends State<DesignSystemTimeWheel> {
  // Flutter's Cupertino picker values, tuned against the native iOS wheel.
  static const _diameterRatio = 1.07;
  static const _squeeze = 1.45;
  static const _overAndUnderCenterOpacity = 0.447;

  late int _hourIndex;
  late int _minuteIndex;
  late int _periodIndex;

  @override
  void initState() {
    super.initState();
    final initial = TimeOfDay.fromDateTime(widget.initialDateTime);
    _hourIndex = widget.use24hFormat
        ? initial.hour
        : (initial.hourOfPeriod == 0 ? 12 : initial.hourOfPeriod) - 1;
    _minuteIndex = initial.minute;
    _periodIndex = initial.period == DayPeriod.am ? 0 : 1;
  }

  void _notifyChanged() {
    final hour = widget.use24hFormat
        ? _hourIndex
        : ((_hourIndex + 1) % 12) + _periodIndex * 12;
    widget.onDateTimeChanged(
      DateTime(
        widget.initialDateTime.year,
        widget.initialDateTime.month,
        widget.initialDateTime.day,
        hour,
        _minuteIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final materialLocalizations = MaterialLocalizations.of(context);
    final pickerStyle = _pickerTextStyle(tokens);
    return SizedBox(
      height: tokens.spacing.step12 + tokens.spacing.step10,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: widget.semanticsLabel,
        liveRegion: widget.semanticsLiveRegion,
        child: Stack(
          children: [
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  height: tokens.spacing.step8,
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tokens.colors.surface.selected,
                      borderRadius: BorderRadius.circular(tokens.radii.l),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _FixedExtentWheelColumn(
                    itemCount: widget.use24hFormat ? 24 : 12,
                    initialItem: _hourIndex,
                    selectedItem: _hourIndex,
                    itemExtent: tokens.spacing.step8,
                    semanticsLabel: materialLocalizations.timePickerHourLabel,
                    labelBuilder: (index) => widget.use24hFormat
                        ? index.toString().padLeft(2, '0')
                        : '${index + 1}',
                    selectedStyle: pickerStyle,
                    unselectedStyle: pickerStyle.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    onSelectedItemChanged: (index) =>
                        setState(() => _hourIndex = index),
                    onScrollEnd: _notifyChanged,
                  ),
                ),
                Text(':', style: pickerStyle),
                Expanded(
                  child: _FixedExtentWheelColumn(
                    itemCount: 60,
                    initialItem: _minuteIndex,
                    selectedItem: _minuteIndex,
                    itemExtent: tokens.spacing.step8,
                    semanticsLabel: materialLocalizations.timePickerMinuteLabel,
                    labelBuilder: (index) => index.toString().padLeft(2, '0'),
                    selectedStyle: pickerStyle,
                    unselectedStyle: pickerStyle.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    onSelectedItemChanged: (index) =>
                        setState(() => _minuteIndex = index),
                    onScrollEnd: _notifyChanged,
                  ),
                ),
                if (!widget.use24hFormat)
                  Expanded(
                    child: _FixedExtentWheelColumn(
                      itemCount: 2,
                      initialItem: _periodIndex,
                      selectedItem: _periodIndex,
                      itemExtent: tokens.spacing.step8,
                      semanticsLabel:
                          '${materialLocalizations.anteMeridiemAbbreviation} / '
                          '${materialLocalizations.postMeridiemAbbreviation}',
                      looping: false,
                      labelBuilder: (index) => index == 0
                          ? MaterialLocalizations.of(
                              context,
                            ).anteMeridiemAbbreviation
                          : MaterialLocalizations.of(
                              context,
                            ).postMeridiemAbbreviation,
                      selectedStyle: pickerStyle,
                      unselectedStyle: pickerStyle.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      onSelectedItemChanged: (index) =>
                          setState(() => _periodIndex = index),
                      onScrollEnd: _notifyChanged,
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

class _FixedExtentWheelColumn extends StatefulWidget {
  const _FixedExtentWheelColumn({
    required this.itemCount,
    required this.initialItem,
    required this.selectedItem,
    required this.itemExtent,
    required this.semanticsLabel,
    required this.labelBuilder,
    required this.selectedStyle,
    required this.unselectedStyle,
    required this.onSelectedItemChanged,
    required this.onScrollEnd,
    this.looping = true,
  });

  final int itemCount;
  final int initialItem;
  final int selectedItem;
  final double itemExtent;
  final String semanticsLabel;
  final String Function(int) labelBuilder;
  final TextStyle selectedStyle;
  final TextStyle unselectedStyle;
  final ValueChanged<int> onSelectedItemChanged;
  final VoidCallback onScrollEnd;
  final bool looping;

  @override
  State<_FixedExtentWheelColumn> createState() =>
      _FixedExtentWheelColumnState();
}

class _FixedExtentWheelColumnState extends State<_FixedExtentWheelColumn> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(initialItem: widget.initialItem);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _adjustedIndex(int delta) {
    if (widget.looping) {
      return (widget.selectedItem + delta) % widget.itemCount;
    }
    final next = widget.selectedItem + delta;
    return next >= 0 && next < widget.itemCount ? next : null;
  }

  void _adjust(int delta) {
    final next = _adjustedIndex(delta);
    if (next == null) return;
    _controller.jumpToItem(next);
    widget.onSelectedItemChanged(next);
    widget.onScrollEnd();
  }

  @override
  Widget build(BuildContext context) {
    final children = List.generate(
      widget.itemCount,
      (index) => Center(
        child: Text(
          widget.labelBuilder(index),
          style: index == widget.selectedItem
              ? widget.selectedStyle
              : widget.unselectedStyle,
        ),
      ),
    );
    final increasedIndex = _adjustedIndex(1);
    final decreasedIndex = _adjustedIndex(-1);
    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      value: widget.labelBuilder(widget.selectedItem),
      increasedValue: increasedIndex == null
          ? null
          : widget.labelBuilder(increasedIndex),
      decreasedValue: decreasedIndex == null
          ? null
          : widget.labelBuilder(decreasedIndex),
      selected: true,
      onIncrease: increasedIndex == null ? null : () => _adjust(1),
      onDecrease: decreasedIndex == null ? null : () => _adjust(-1),
      child: ExcludeSemantics(
        child: NotificationListener<ScrollEndNotification>(
          onNotification: (_) {
            widget.onScrollEnd();
            return false;
          },
          child: ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: widget.itemExtent,
            physics: const FixedExtentScrollPhysics(),
            diameterRatio: _DesignSystemTimeWheelState._diameterRatio,
            squeeze: _DesignSystemTimeWheelState._squeeze,
            overAndUnderCenterOpacity:
                _DesignSystemTimeWheelState._overAndUnderCenterOpacity,
            onSelectedItemChanged: widget.onSelectedItemChanged,
            childDelegate: widget.looping
                ? ListWheelChildLoopingListDelegate(children: children)
                : ListWheelChildListDelegate(children: children),
          ),
        ),
      ),
    );
  }
}

/// Token-backed hour/minute duration wheel used by estimate modals.
class DesignSystemDurationWheel extends StatelessWidget {
  const DesignSystemDurationWheel({
    required this.initialDuration,
    required this.onDurationChanged,
    this.semanticsLabel,
    this.semanticsLiveRegion = false,
    super.key,
  });

  final Duration initialDuration;
  final ValueChanged<Duration> onDurationChanged;
  final String? semanticsLabel;
  final bool semanticsLiveRegion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      height: tokens.spacing.step12 + tokens.spacing.step9,
      child: CupertinoTheme(
        data: CupertinoThemeData(
          textTheme: CupertinoTextThemeData(
            pickerTextStyle: _pickerTextStyle(tokens),
          ),
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: semanticsLabel,
          liveRegion: semanticsLiveRegion,
          child: CupertinoTimerPicker(
            initialTimerDuration: initialDuration,
            mode: CupertinoTimerPickerMode.hm,
            itemExtent: tokens.spacing.step9,
            changeReportingBehavior: ChangeReportingBehavior.onScrollEnd,
            selectionOverlayBuilder:
                (
                  context, {
                  required selectedIndex,
                  required columnCount,
                }) => _selectionOverlay(
                  tokens,
                  selectedIndex: selectedIndex,
                  columnCount: columnCount,
                ),
            onTimerDurationChanged: onDurationChanged,
          ),
        ),
      ),
    );
  }
}

TextStyle _pickerTextStyle(DsTokens tokens) =>
    tokens.typography.styles.subtitle.subtitle1.copyWith(
      color: tokens.colors.text.highEmphasis,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

Widget _selectionOverlay(
  DsTokens tokens, {
  required int selectedIndex,
  required int columnCount,
}) => CupertinoPickerDefaultSelectionOverlay(
  background: tokens.colors.surface.selected,
  capStartEdge: selectedIndex == 0,
  capEndEdge: selectedIndex == columnCount - 1,
);
