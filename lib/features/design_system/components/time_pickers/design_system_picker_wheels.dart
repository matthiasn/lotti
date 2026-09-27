import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/time_pickers/time_wheel_rollover.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Token-backed time-of-day wheel shared by date/time modals.
///
/// It keeps the platform wheel interaction while standardizing value type,
/// row geometry, selected-row color, and settled-change reporting.
///
/// The drums behave like one continuous clock: rolling the minute drum past
/// 59 → 00 animates the hour forwards, rolling it back past 00 → 59 animates
/// the hour backwards (14:00 → 13:59), crossing AM/PM on a 12-hour wheel. The
/// date of [initialDateTime] is kept even when the hour wraps past midnight.
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

// Flutter's Cupertino picker values, tuned against the native iOS wheel.
const _diameterRatio = 1.07;
const _squeeze = 1.45;
const _overAndUnderCenterOpacity = 0.447;
const _hourMaxFlingRowsPerSecond = 8.0;
const _minuteMaxFlingRowsPerSecond = 20.0;

class _DesignSystemTimeWheelState extends State<DesignSystemTimeWheel> {
  final _hourColumn = GlobalKey<_FixedExtentWheelColumnState>();
  final _periodColumn = GlobalKey<_FixedExtentWheelColumnState>();
  late int _hourIndex;
  late int _minuteIndex;
  late int _periodIndex;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDateTime;
    final wheelHour = timeWheelHourFrom24(
      initial.hour,
      use24h: widget.use24hFormat,
    );
    _hourIndex = wheelHour.hourIndex;
    _minuteIndex = initial.minute;
    _periodIndex = wheelHour.periodIndex;
  }

  /// Records a minute that wrapped onto [minute] and carries the wrap into the
  /// hour (and AM/PM) drums.
  ///
  /// Minute and hour are both recorded before the hour drum moves — moving it
  /// can report the time synchronously — so no report pairs one with a stale
  /// other, and a second wrap in quick succession builds on this one's target.
  void _handleMinuteWrapped(int minute, int direction) {
    _minuteIndex = minute;
    final rolled = rollTimeWheelHour(
      (hourIndex: _hourIndex, periodIndex: _periodIndex),
      direction,
      use24h: widget.use24hFormat,
    );
    _hourIndex = rolled.hourIndex;
    _periodIndex = rolled.periodIndex;
    _hourColumn.currentState?.animateToIndex(rolled.hourIndex);
    _periodColumn.currentState?.animateToIndex(rolled.periodIndex);
  }

  void _notifyChanged() {
    final hour = timeWheelHourTo24(
      (hourIndex: _hourIndex, periodIndex: _periodIndex),
      use24h: widget.use24hFormat,
    );
    final initial = widget.initialDateTime;
    final changed = initial.isUtc
        ? DateTime.utc(
            initial.year,
            initial.month,
            initial.day,
            hour,
            _minuteIndex,
          )
        : DateTime(
            initial.year,
            initial.month,
            initial.day,
            hour,
            _minuteIndex,
          );
    widget.onDateTimeChanged(changed);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final materialLocalizations = MaterialLocalizations.of(context);
    final styles = _wheelStyles(tokens);
    return _WheelFrame(
      height: tokens.spacing.step12 + tokens.spacing.step10,
      rowExtent: tokens.spacing.step8,
      semanticsLabel: widget.semanticsLabel,
      semanticsLiveRegion: widget.semanticsLiveRegion,
      children: [
        Expanded(
          child: _FixedExtentWheelColumn(
            key: _hourColumn,
            itemCount: widget.use24hFormat ? 24 : 12,
            initialItem: _hourIndex,
            itemExtent: tokens.spacing.step8,
            maxFlingRowsPerSecond: _hourMaxFlingRowsPerSecond,
            semanticsLabel: materialLocalizations.timePickerHourLabel,
            labelBuilder: (index) => widget.use24hFormat
                ? index.toString().padLeft(2, '0')
                : '${index + 1}',
            styles: styles,
            onSelectedItemChanged: (index) => _hourIndex = index,
            onScrollEnd: _notifyChanged,
          ),
        ),
        Text(':', style: styles.selected),
        Expanded(
          child: _FixedExtentWheelColumn(
            itemCount: 60,
            initialItem: _minuteIndex,
            itemExtent: tokens.spacing.step8,
            maxFlingRowsPerSecond: _minuteMaxFlingRowsPerSecond,
            semanticsLabel: materialLocalizations.timePickerMinuteLabel,
            labelBuilder: (index) => index.toString().padLeft(2, '0'),
            styles: styles,
            onSelectedItemChanged: (index) => _minuteIndex = index,
            onWrapped: _handleMinuteWrapped,
            onScrollEnd: _notifyChanged,
          ),
        ),
        if (!widget.use24hFormat)
          Expanded(
            child: _FixedExtentWheelColumn(
              key: _periodColumn,
              itemCount: 2,
              initialItem: _periodIndex,
              itemExtent: tokens.spacing.step8,
              maxFlingRowsPerSecond: 0,
              semanticsLabel:
                  '${materialLocalizations.anteMeridiemAbbreviation} / '
                  '${materialLocalizations.postMeridiemAbbreviation}',
              looping: false,
              labelBuilder: (index) => index == 0
                  ? materialLocalizations.anteMeridiemAbbreviation
                  : materialLocalizations.postMeridiemAbbreviation,
              styles: styles,
              onSelectedItemChanged: (index) => _periodIndex = index,
              onScrollEnd: _notifyChanged,
            ),
          ),
      ],
    );
  }
}

/// The chrome every drum shares: a fixed-height box holding the selection
/// band behind a row of columns, inside the semantics container the host
/// names.
class _WheelFrame extends StatelessWidget {
  const _WheelFrame({
    required this.height,
    required this.rowExtent,
    required this.semanticsLabel,
    required this.semanticsLiveRegion,
    required this.children,
  });

  final double height;
  final double rowExtent;
  final String? semanticsLabel;
  final bool semanticsLiveRegion;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      height: height,
      child: Semantics(
        container: true,
        explicitChildNodes: true,
        label: semanticsLabel,
        liveRegion: semanticsLiveRegion,
        child: Stack(
          children: [
            IgnorePointer(
              child: Center(
                child: SizedBox(
                  height: rowExtent,
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
            Row(children: children),
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
    required this.itemExtent,
    required this.maxFlingRowsPerSecond,
    required this.semanticsLabel,
    required this.labelBuilder,
    required this.styles,
    required this.onSelectedItemChanged,
    required this.onScrollEnd,
    this.semanticsValueBuilder,
    this.labelAlignment = Alignment.center,
    this.onWrapped,
    this.looping = true,
    super.key,
  });

  final int itemCount;
  final int initialItem;
  final double itemExtent;
  final double maxFlingRowsPerSecond;
  final String semanticsLabel;
  final String Function(int) labelBuilder;

  /// What assistive technology reads for a row; [labelBuilder] when null.
  final String Function(int)? semanticsValueBuilder;
  final AlignmentGeometry labelAlignment;
  final _WheelStyles styles;
  final ValueChanged<int> onSelectedItemChanged;
  final VoidCallback onScrollEnd;

  /// Called instead of [onSelectedItemChanged] when a looping column wraps;
  /// see [TimeWheelColumnDriver.onWrapped].
  final TimeWheelWrapped? onWrapped;
  final bool looping;

  @override
  State<_FixedExtentWheelColumn> createState() =>
      _FixedExtentWheelColumnState();
}

class _FixedExtentWheelColumnState extends State<_FixedExtentWheelColumn> {
  late final TimeWheelColumnDriver _driver;
  late final FocusNode _focusNode;
  late final Listenable _visualState;
  late List<Widget> _children;
  var _pointerScrollDistance = 0.0;

  FixedExtentScrollController get _controller => _driver.controller;
  ValueNotifier<int> get _selectedItem => _driver.selectedIndex;

  @override
  void initState() {
    super.initState();
    _driver = TimeWheelColumnDriver(
      itemCount: widget.itemCount,
      initialIndex: widget.initialItem,
      looping: widget.looping,
      onSelectedIndexChanged: (index) => widget.onSelectedItemChanged(index),
      onWrapped: widget.onWrapped == null
          ? null
          : (index, direction) => widget.onWrapped!(index, direction),
    );
    _focusNode = FocusNode(debugLabel: widget.semanticsLabel);
    _visualState = Listenable.merge([_selectedItem, _focusNode]);
    _children = _buildChildren();
  }

  @override
  void didUpdateWidget(covariant _FixedExtentWheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount ||
        widget.styles != oldWidget.styles) {
      _children = _buildChildren();
    }
  }

  @override
  void dispose() {
    _driver.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Moves the column to row [index] because a neighbouring column wrapped.
  void animateToIndex(int index) => _driver.animateToIndex(
    index,
    animate: !MediaQuery.disableAnimationsOf(context),
  );

  void _adjust(int delta) {
    if (_driver.stepBy(delta)) widget.onScrollEnd();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _adjust(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _adjust(1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      _handleResolvedPointerScroll,
    );
  }

  void _handleResolvedPointerScroll(PointerSignalEvent event) {
    final scrollEvent = event as PointerScrollEvent
      ..respond(allowPlatformDefault: false);
    if (!_controller.hasClients) return;

    _pointerScrollDistance += scrollEvent.scrollDelta.dy;
    if (_pointerScrollDistance.abs() < widget.itemExtent / 2) return;

    final direction = _pointerScrollDistance.sign;
    _pointerScrollDistance = 0;
    _controller.position.pointerScroll(direction * widget.itemExtent);
  }

  List<Widget> _buildChildren() => List.generate(
    widget.itemCount,
    (index) => Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: _handlePointerSignal,
      child: SizedBox.expand(
        child: Align(
          alignment: widget.labelAlignment,
          child: AnimatedBuilder(
            animation: _visualState,
            builder: (context, _) => Text(
              widget.labelBuilder(index),
              style: index == _selectedItem.value
                  ? _focusNode.hasFocus
                        ? widget.styles.focused
                        : widget.styles.selected
                  : widget.styles.unselected,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _focusNode.requestFocus(),
        child: AnimatedBuilder(
          animation: _visualState,
          builder: (context, _) {
            final selectedItem = _selectedItem.value;
            final increasedIndex = _driver.indexFor(1);
            final decreasedIndex = _driver.indexFor(-1);
            final valueOf = widget.semanticsValueBuilder ?? widget.labelBuilder;
            return Semantics(
              container: true,
              label: widget.semanticsLabel,
              value: valueOf(selectedItem),
              increasedValue: increasedIndex == null
                  ? null
                  : valueOf(increasedIndex),
              decreasedValue: decreasedIndex == null
                  ? null
                  : valueOf(decreasedIndex),
              focusable: true,
              focused: _focusNode.hasFocus,
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
                    physics: widget.maxFlingRowsPerSecond == 0
                        ? const _PreciseFixedExtentScrollPhysics()
                        : _ControlledFixedExtentScrollPhysics(
                            itemExtent: widget.itemExtent,
                            maxFlingRowsPerSecond: widget.maxFlingRowsPerSecond,
                          ),
                    diameterRatio: _diameterRatio,
                    squeeze: _squeeze,
                    overAndUnderCenterOpacity: _overAndUnderCenterOpacity,
                    onSelectedItemChanged: _driver.handleSelectedItemChanged,
                    dragStartBehavior: DragStartBehavior.down,
                    childDelegate: widget.looping
                        ? ListWheelChildLoopingListDelegate(children: _children)
                        : ListWheelChildListDelegate(children: _children),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Snaps to the nearest row at release without adding slot-machine momentum.
class _PreciseFixedExtentScrollPhysics extends FixedExtentScrollPhysics {
  const _PreciseFixedExtentScrollPhysics({super.parent});

  @override
  _PreciseFixedExtentScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _PreciseFixedExtentScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => super.createBallisticSimulation(position, 0);
}

/// Preserves wheel momentum while preventing extreme desktop fling velocity.
class _ControlledFixedExtentScrollPhysics extends FixedExtentScrollPhysics {
  const _ControlledFixedExtentScrollPhysics({
    required this.itemExtent,
    required this.maxFlingRowsPerSecond,
    super.parent,
  });

  final double itemExtent;
  final double maxFlingRowsPerSecond;

  @override
  double get maxFlingVelocity => itemExtent * maxFlingRowsPerSecond;

  @override
  _ControlledFixedExtentScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _ControlledFixedExtentScrollPhysics(
        itemExtent: itemExtent,
        maxFlingRowsPerSecond: maxFlingRowsPerSecond,
        parent: buildParent(ancestor),
      );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) => super.createBallisticSimulation(
    position,
    velocity.clamp(-maxFlingVelocity, maxFlingVelocity),
  );
}

/// Token-backed hour/minute duration wheel used by the duration modals.
///
/// The minute drum carries into the hour drum the way [DesignSystemTimeWheel]
/// does — rolling back past 00 → 59 animates the hour down (1:05 → 0:59),
/// rolling forward past 59 → 00 animates it up — through the same
/// [TimeWheelColumnDriver]. A duration has no midnight to wrap across, so the
/// hour drum runs 0–23 without looping, and a minute wrap at either end
/// leaves the hour where it is.
class DesignSystemDurationWheel extends StatefulWidget {
  const DesignSystemDurationWheel({
    required this.initialDuration,
    required this.onDurationChanged,
    this.semanticsLabel,
    this.semanticsLiveRegion = false,
    super.key,
  });

  /// Where the drums open; anything past 23:59 opens on 23:59.
  final Duration initialDuration;

  /// Called with the settled duration once a drum comes to rest.
  final ValueChanged<Duration> onDurationChanged;
  final String? semanticsLabel;
  final bool semanticsLiveRegion;

  @override
  State<DesignSystemDurationWheel> createState() =>
      _DesignSystemDurationWheelState();
}

class _DesignSystemDurationWheelState extends State<DesignSystemDurationWheel> {
  static const _hourCount = 24;
  final _hourColumn = GlobalKey<_FixedExtentWheelColumnState>();
  late int _hours;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    final minutes = widget.initialDuration.inMinutes.clamp(
      0,
      _hourCount * 60 - 1,
    );
    _hours = minutes ~/ 60;
    _minutes = minutes % 60;
  }

  /// Records a minute that wrapped onto [minute] and carries the wrap into the
  /// hour drum, recording the hour before the drum moves for the same reason
  /// the time wheel does: moving it can report synchronously.
  void _handleMinuteWrapped(int minute, int direction) {
    _minutes = minute;
    final hours = (_hours + direction).clamp(0, _hourCount - 1);
    if (hours == _hours) return;
    _hours = hours;
    _hourColumn.currentState?.animateToIndex(hours);
  }

  void _notifyChanged() {
    // Rebuilds the unit labels, whose plurals follow the drums.
    setState(() {});
    widget.onDurationChanged(Duration(hours: _hours, minutes: _minutes));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final localizations = CupertinoLocalizations.of(context);
    final materialLocalizations = MaterialLocalizations.of(context);
    final styles = _wheelStyles(tokens);

    // The number right-aligned against its unit, as the platform timer
    // picker lays them out. The unit gets its own half, so a plural longer
    // than its singular never shifts the drum.
    Widget half({required Widget column, required String unit}) => Expanded(
      child: Row(
        children: [
          Expanded(child: column),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: ExcludeSemantics(
              child: Text(unit, style: styles.selected),
            ),
          ),
        ],
      ),
    );

    return _WheelFrame(
      height: tokens.spacing.step12 + tokens.spacing.step9,
      rowExtent: tokens.spacing.step9,
      semanticsLabel: widget.semanticsLabel,
      semanticsLiveRegion: widget.semanticsLiveRegion,
      children: [
        half(
          column: _FixedExtentWheelColumn(
            key: _hourColumn,
            itemCount: _hourCount,
            initialItem: _hours,
            itemExtent: tokens.spacing.step9,
            maxFlingRowsPerSecond: _hourMaxFlingRowsPerSecond,
            semanticsLabel: materialLocalizations.timePickerHourLabel,
            looping: false,
            labelAlignment: AlignmentDirectional.centerEnd,
            labelBuilder: localizations.timerPickerHour,
            semanticsValueBuilder: (hours) =>
                '${localizations.timerPickerHour(hours)} '
                '${localizations.timerPickerHourLabel(hours) ?? ''}',
            styles: styles,
            onSelectedItemChanged: (index) => _hours = index,
            onScrollEnd: _notifyChanged,
          ),
          unit: localizations.timerPickerHourLabel(_hours) ?? '',
        ),
        half(
          column: _FixedExtentWheelColumn(
            itemCount: 60,
            initialItem: _minutes,
            itemExtent: tokens.spacing.step9,
            maxFlingRowsPerSecond: _minuteMaxFlingRowsPerSecond,
            semanticsLabel: materialLocalizations.timePickerMinuteLabel,
            labelAlignment: AlignmentDirectional.centerEnd,
            labelBuilder: localizations.timerPickerMinute,
            semanticsValueBuilder: (minutes) =>
                '${localizations.timerPickerMinute(minutes)} '
                '${localizations.timerPickerMinuteLabel(minutes) ?? ''}',
            styles: styles,
            onSelectedItemChanged: (index) => _minutes = index,
            onWrapped: _handleMinuteWrapped,
            onScrollEnd: _notifyChanged,
          ),
          unit: localizations.timerPickerMinuteLabel(_minutes) ?? '',
        ),
      ],
    );
  }
}

/// The three looks of a drum row: settled under the band, settled while its
/// column has keyboard focus, and off the band.
typedef _WheelStyles = ({
  TextStyle selected,
  TextStyle focused,
  TextStyle unselected,
});

_WheelStyles _wheelStyles(DsTokens tokens) {
  final base = tokens.typography.styles.subtitle.subtitle1.copyWith(
    color: tokens.colors.text.highEmphasis,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  return (
    selected: base,
    focused: base.copyWith(color: tokens.colors.interactive.enabled),
    unselected: base.copyWith(color: tokens.colors.text.mediumEmphasis),
  );
}
