import 'package:lotti/features/design_system/components/time_pickers/time_wheel_rollover.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

enum DesignSystemTimeFormat {
  twelveHour,
  twentyFourHour,
}

/// The design-system's wheel-style time picker — scrollable hour/minute (and
/// AM/PM) columns.
///
/// Seeds its columns from [initialTime] (or the current time) and reports each
/// change via [onTimeChanged] as a [TimeOfDay]. [format] selects
/// [DesignSystemTimeFormat] (12-hour with an AM/PM wheel or 24-hour);
/// [semanticsLabel] labels the picker.
///
/// Rolling the minute column past 59 → 00 (or back past 00 → 59) animates the
/// hour column (and AM/PM) along with it, like a continuous clock.
class DesignSystemTimePicker extends StatefulWidget {
  const DesignSystemTimePicker({
    required this.onTimeChanged,
    this.initialTime,
    this.format = DesignSystemTimeFormat.twentyFourHour,
    this.semanticsLabel,
    super.key,
  });

  final ValueChanged<TimeOfDay> onTimeChanged;
  final TimeOfDay? initialTime;
  final DesignSystemTimeFormat format;
  final String? semanticsLabel;

  @override
  State<DesignSystemTimePicker> createState() => _DesignSystemTimePickerState();
}

class _DesignSystemTimePickerState extends State<DesignSystemTimePicker> {
  final _hourColumn = GlobalKey<_DrumColumnState>();
  final _periodColumn = GlobalKey<_DrumColumnState>();
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedPeriod; // 0 = AM, 1 = PM

  bool get _use24h => widget.format == DesignSystemTimeFormat.twentyFourHour;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTime ?? TimeOfDay.now();
    final wheelHour = timeWheelHourFrom24(initial.hour, use24h: _use24h);
    _selectedHour = wheelHour.hourIndex;
    _selectedPeriod = wheelHour.periodIndex;
    _selectedMinute = initial.minute;
  }

  void _notifyTimeChanged() {
    final hour = timeWheelHourTo24(
      (hourIndex: _selectedHour, periodIndex: _selectedPeriod),
      use24h: _use24h,
    );
    widget.onTimeChanged(TimeOfDay(hour: hour, minute: _selectedMinute));
  }

  /// Carries a minute-column wrap into the hour (and AM/PM) columns. The new
  /// hour is recorded before the hour column animates, so the reported time
  /// is right straight away and quick successive wraps chain.
  void _handleMinuteWrapped(int direction) {
    final rolled = rollTimeWheelHour(
      (hourIndex: _selectedHour, periodIndex: _selectedPeriod),
      direction,
      use24h: _use24h,
    );
    _selectedHour = rolled.hourIndex;
    _selectedPeriod = rolled.periodIndex;
    _hourColumn.currentState?.animateToIndex(rolled.hourIndex);
    _periodColumn.currentState?.animateToIndex(rolled.periodIndex);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final materialLocalizations = MaterialLocalizations.of(context);
    final columnGap = // 27px
        tokens.spacing.step6 + tokens.spacing.step1 + tokens.spacing.step1 / 2;
    final is12h = !_use24h;
    final hourCount = is12h ? 12 : 24;

    return Semantics(
      container: true,
      label: widget.semanticsLabel,
      child: SizedBox(
        height: 212,
        child: Stack(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.colors.surface.enabled,
              ),
              child: const SizedBox.expand(),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DrumColumn(
                  key: _hourColumn,
                  itemCount: hourCount,
                  initialItem: _selectedHour,
                  labelBuilder: (index) => is12h ? '${index + 1}' : '$index',
                  onSelectedItemChanged: (index) {
                    _selectedHour = index;
                    _notifyTimeChanged();
                  },
                ),
                SizedBox(width: columnGap),
                _DrumColumn(
                  itemCount: 60,
                  initialItem: _selectedMinute,
                  labelBuilder: (index) => '$index',
                  onSelectedItemChanged: (index) {
                    _selectedMinute = index;
                    _notifyTimeChanged();
                  },
                  onWrapped: _handleMinuteWrapped,
                ),
                if (is12h) ...[
                  SizedBox(width: columnGap),
                  _DrumColumn(
                    key: _periodColumn,
                    itemCount: 2,
                    initialItem: _selectedPeriod,
                    looping: false,
                    labelBuilder: (index) => index == 0
                        ? materialLocalizations.anteMeridiemAbbreviation
                        : materialLocalizations.postMeridiemAbbreviation,
                    onSelectedItemChanged: (index) {
                      _selectedPeriod = index;
                      _notifyTimeChanged();
                    },
                  ),
                ],
              ],
            ),
            _SelectionOverlay(tokens: tokens),
          ],
        ),
      ),
    );
  }
}

class _SelectionOverlay extends StatelessWidget {
  const _SelectionOverlay({required this.tokens});

  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          height: 31,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: tokens.colors.decorative.level01,
                  width: 0.5,
                ),
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

const _kItemExtent = 31.0;
const _kDiameterRatio = 1.2;
const _kMagnification = 1.15;
const _kOverAndUnderCenterOpacity = 0.35;
const _kSqueeze = 1.1;

class _DrumColumn extends StatefulWidget {
  const _DrumColumn({
    required this.itemCount,
    required this.initialItem,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
    this.onWrapped,
    this.looping = true,
    super.key,
  });

  final int itemCount;
  final int initialItem;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;
  final ValueChanged<int>? onWrapped;
  final bool looping;

  @override
  State<_DrumColumn> createState() => _DrumColumnState();
}

class _DrumColumnState extends State<_DrumColumn> {
  late final TimeWheelColumnDriver _driver;

  @override
  void initState() {
    super.initState();
    _driver = TimeWheelColumnDriver(
      itemCount: widget.itemCount,
      initialIndex: widget.initialItem,
      looping: widget.looping,
      onSelectedIndexChanged: (index) => widget.onSelectedItemChanged(index),
      onWrapped: (direction) => widget.onWrapped?.call(direction),
    );
  }

  @override
  void dispose() {
    _driver.dispose();
    super.dispose();
  }

  /// Moves the column to row [index] because a neighbouring column wrapped.
  void animateToIndex(int index) => _driver.animateToIndex(
    index,
    animate: !MediaQuery.disableAnimationsOf(context),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SizedBox(
      width: 50,
      child: ListWheelScrollView.useDelegate(
        controller: _driver.controller,
        itemExtent: _kItemExtent,
        diameterRatio: _kDiameterRatio,
        magnification: _kMagnification,
        overAndUnderCenterOpacity: _kOverAndUnderCenterOpacity,
        squeeze: _kSqueeze,
        useMagnifier: true,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: _driver.handleSelectedItemChanged,
        childDelegate: () {
          final children = List.generate(
            widget.itemCount,
            (index) => _DrumItem(
              label: widget.labelBuilder(index),
              tokens: tokens,
            ),
          );
          return widget.looping
              ? ListWheelChildLoopingListDelegate(children: children)
              : ListWheelChildListDelegate(children: children);
        }(),
      ),
    );
  }
}

class _DrumItem extends StatelessWidget {
  const _DrumItem({
    required this.label,
    required this.tokens,
  });

  final String label;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}
