import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const _hourMaxFlingRowsPerSecond = 8.0;
  static const _minuteMaxFlingRowsPerSecond = 20.0;
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
                    maxFlingRowsPerSecond: _hourMaxFlingRowsPerSecond,
                    semanticsLabel: materialLocalizations.timePickerHourLabel,
                    labelBuilder: (index) => widget.use24hFormat
                        ? index.toString().padLeft(2, '0')
                        : '${index + 1}',
                    selectedStyle: pickerStyle,
                    focusedStyle: pickerStyle.copyWith(
                      color: tokens.colors.interactive.enabled,
                    ),
                    unselectedStyle: pickerStyle.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    onSelectedItemChanged: (index) => _hourIndex = index,
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
                    maxFlingRowsPerSecond: _minuteMaxFlingRowsPerSecond,
                    semanticsLabel: materialLocalizations.timePickerMinuteLabel,
                    labelBuilder: (index) => index.toString().padLeft(2, '0'),
                    selectedStyle: pickerStyle,
                    focusedStyle: pickerStyle.copyWith(
                      color: tokens.colors.interactive.enabled,
                    ),
                    unselectedStyle: pickerStyle.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    onSelectedItemChanged: (index) => _minuteIndex = index,
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
                      maxFlingRowsPerSecond: 0,
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
                      focusedStyle: pickerStyle.copyWith(
                        color: tokens.colors.interactive.enabled,
                      ),
                      unselectedStyle: pickerStyle.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                      onSelectedItemChanged: (index) => _periodIndex = index,
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
    required this.maxFlingRowsPerSecond,
    required this.semanticsLabel,
    required this.labelBuilder,
    required this.selectedStyle,
    required this.focusedStyle,
    required this.unselectedStyle,
    required this.onSelectedItemChanged,
    required this.onScrollEnd,
    this.looping = true,
  });

  final int itemCount;
  final int initialItem;
  final int selectedItem;
  final double itemExtent;
  final double maxFlingRowsPerSecond;
  final String semanticsLabel;
  final String Function(int) labelBuilder;
  final TextStyle selectedStyle;
  final TextStyle focusedStyle;
  final TextStyle unselectedStyle;
  final ValueChanged<int> onSelectedItemChanged;
  final VoidCallback onScrollEnd;
  final bool looping;

  @override
  State<_FixedExtentWheelColumn> createState() =>
      _FixedExtentWheelColumnState();
}

class _FixedExtentWheelColumnState extends State<_FixedExtentWheelColumn> {
  static const _loopingTurns = 1000;

  late final FixedExtentScrollController _controller;
  late final FocusNode _focusNode;
  late final ValueNotifier<int> _selectedItem;
  late final Listenable _visualState;
  late List<Widget> _children;
  var _pointerScrollDistance = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.looping
          ? widget.itemCount * _loopingTurns + widget.initialItem
          : widget.initialItem,
    );
    _focusNode = FocusNode(debugLabel: widget.semanticsLabel);
    _selectedItem = ValueNotifier(widget.selectedItem);
    _visualState = Listenable.merge([_selectedItem, _focusNode]);
    _children = _buildChildren();
  }

  @override
  void didUpdateWidget(covariant _FixedExtentWheelColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount ||
        widget.selectedStyle != oldWidget.selectedStyle ||
        widget.focusedStyle != oldWidget.focusedStyle ||
        widget.unselectedStyle != oldWidget.unselectedStyle) {
      _children = _buildChildren();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _selectedItem.dispose();
    super.dispose();
  }

  int? _adjustedIndex(int delta) {
    if (widget.looping) {
      return (_selectedItem.value + delta) % widget.itemCount;
    }
    final next = _selectedItem.value + delta;
    return next >= 0 && next < widget.itemCount ? next : null;
  }

  void _handleSelectedItemChanged(int index) {
    if (_selectedItem.value == index) return;
    _selectedItem.value = index;
    widget.onSelectedItemChanged(index);
  }

  void _adjust(int delta) {
    final next = _adjustedIndex(delta);
    if (next == null) return;
    _controller.jumpToItem(
      widget.looping ? _controller.selectedItem + delta : next,
    );
    _handleSelectedItemChanged(next);
    widget.onScrollEnd();
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
        child: Center(
          child: AnimatedBuilder(
            animation: _visualState,
            builder: (context, _) => Text(
              widget.labelBuilder(index),
              style: index == _selectedItem.value
                  ? _focusNode.hasFocus
                        ? widget.focusedStyle
                        : widget.selectedStyle
                  : widget.unselectedStyle,
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
            final increasedIndex = _adjustedIndex(1);
            final decreasedIndex = _adjustedIndex(-1);
            return Semantics(
              container: true,
              label: widget.semanticsLabel,
              value: widget.labelBuilder(selectedItem),
              increasedValue: increasedIndex == null
                  ? null
                  : widget.labelBuilder(increasedIndex),
              decreasedValue: decreasedIndex == null
                  ? null
                  : widget.labelBuilder(decreasedIndex),
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
                    diameterRatio: _DesignSystemTimeWheelState._diameterRatio,
                    squeeze: _DesignSystemTimeWheelState._squeeze,
                    overAndUnderCenterOpacity:
                        _DesignSystemTimeWheelState._overAndUnderCenterOpacity,
                    onSelectedItemChanged: _handleSelectedItemChanged,
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
