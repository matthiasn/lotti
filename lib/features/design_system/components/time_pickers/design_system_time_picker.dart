import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

enum DesignSystemTimeFormat {
  twelveHour,
  twentyFourHour,
}

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
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedPeriod; // 0 = AM, 1 = PM

  @override
  void initState() {
    super.initState();
    final initial = widget.initialTime ?? TimeOfDay.now();
    if (widget.format == DesignSystemTimeFormat.twelveHour) {
      _selectedHour = initial.hourOfPeriod - 1;
      _selectedPeriod = initial.period == DayPeriod.am ? 0 : 1;
    } else {
      _selectedHour = initial.hour;
      _selectedPeriod = 0;
    }
    _selectedMinute = initial.minute;
  }

  void _notifyTimeChanged() {
    final hour = widget.format == DesignSystemTimeFormat.twelveHour
        ? ((_selectedHour + 1) % 12) + _selectedPeriod * 12
        : _selectedHour;
    widget.onTimeChanged(TimeOfDay(hour: hour, minute: _selectedMinute));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final is12h = widget.format == DesignSystemTimeFormat.twelveHour;
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
                  itemCount: hourCount,
                  initialItem: _selectedHour,
                  labelBuilder: (index) => is12h ? '${index + 1}' : '$index',
                  onSelectedItemChanged: (index) {
                    _selectedHour = index;
                    _notifyTimeChanged();
                  },
                ),
                const SizedBox(width: 27),
                _DrumColumn(
                  itemCount: 60,
                  initialItem: _selectedMinute,
                  labelBuilder: (index) => '$index',
                  onSelectedItemChanged: (index) {
                    _selectedMinute = index;
                    _notifyTimeChanged();
                  },
                ),
                if (is12h) ...[
                  const SizedBox(width: 27),
                  _DrumColumn(
                    itemCount: 2,
                    initialItem: _selectedPeriod,
                    looping: false,
                    labelBuilder: (index) => index == 0 ? 'AM' : 'PM',
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
const _kDiameterRatio = 1.5;
const _kMagnification = 1.15;

class _DrumColumn extends StatefulWidget {
  const _DrumColumn({
    required this.itemCount,
    required this.initialItem,
    required this.labelBuilder,
    required this.onSelectedItemChanged,
    this.looping = true,
  });

  final int itemCount;
  final int initialItem;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onSelectedItemChanged;
  final bool looping;

  @override
  State<_DrumColumn> createState() => _DrumColumnState();
}

class _DrumColumnState extends State<_DrumColumn> {
  late final FixedExtentScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController(
      initialItem: widget.initialItem,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SizedBox(
      width: 50,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: _kItemExtent,
        diameterRatio: _kDiameterRatio,
        magnification: _kMagnification,
        useMagnifier: true,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: widget.onSelectedItemChanged,
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
