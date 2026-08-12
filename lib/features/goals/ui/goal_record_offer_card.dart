import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/model/goal_measurable_record_offer.dart';
import 'package:lotti/features/goals/state/goal_measurable_capture_state.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

class GoalRecordOfferCard extends ConsumerStatefulWidget {
  const GoalRecordOfferCard({
    required this.agentId,
    required this.agentName,
    required this.offer,
    required this.measurable,
    super.key,
  });

  final String agentId;
  final String agentName;
  final GoalMeasurableRecordOffer offer;
  final MeasurableDataType measurable;

  @override
  ConsumerState<GoalRecordOfferCard> createState() =>
      _GoalRecordOfferCardState();
}

class _GoalRecordOfferCardState extends ConsumerState<GoalRecordOfferCard> {
  late List<GoalMeasurableRecordItem> _items;
  late List<TextEditingController> _controllers;
  late List<bool> _selected;
  late Future<bool> _hasConflict;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = [...widget.offer.items];
    _controllers = [
      for (final item in _items)
        TextEditingController(text: _formatEditable(item.value)),
    ];
    _selected = [for (final _ in _items) true];
    _hasConflict = _loadConflict();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatEditable(num value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Future<bool> _loadConflict({List<GoalMeasurableRecordItem>? items}) async {
    final checkedItems =
        items ??
        [
          for (var index = 0; index < _items.length; index++)
            if (_selected[index]) _items[index],
        ];
    if (checkedItems.isEmpty) return false;
    final selectedDays = checkedItems.map((item) => item.day).toList()..sort();
    final start = DateTime(
      selectedDays.first.year,
      selectedDays.first.month,
      selectedDays.first.day,
    );
    final end = DateTime(
      selectedDays.last.year,
      selectedDays.last.month,
      selectedDays.last.day + 1,
    );
    final rows = await ref
        .read(journalDbProvider)
        .getMeasurementsByType(
          type: widget.offer.dataTypeId,
          rangeStart: start,
          rangeEnd: end,
        );
    final offeredDays = {for (final item in checkedItems) item.day};
    return rows.whereType<MeasurementEntry>().any((entry) {
      final date = entry.data.dateFrom;
      final day = DateTime.utc(date.year, date.month, date.day);
      return offeredDays.contains(day);
    });
  }

  Future<void> _dismiss() async {
    if (_saving) return;
    setState(() => _saving = true);
    await ref
        .read(goalMeasurableCaptureServiceProvider)
        .dismiss(agentId: widget.agentId, offer: widget.offer);
    ref.invalidate(goalMeasurableCaptureDecisionsProvider(widget.agentId));
  }

  Future<void> _record() async {
    if (_saving) return;
    final selectedItems = <GoalMeasurableRecordItem>[];
    for (var index = 0; index < _items.length; index++) {
      if (!_selected[index]) continue;
      final value = num.tryParse(
        _controllers[index].text.trim().replaceAll(',', '.'),
      );
      if (value == null || value <= 0) {
        setState(() => _error = context.messages.goalRecordOfferInvalidValue);
        return;
      }
      selectedItems.add(_items[index].copyWith(value: value));
    }
    if (selectedItems.isEmpty) {
      setState(() => _error = context.messages.goalRecordOfferNothingSelected);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    // The initial read keeps the card responsive, but confirmation must fence
    // a measurement that arrived from another device while the offer sat open.
    final conflict = await _loadConflict(items: selectedItems);
    if (!mounted) return;
    if (conflict) {
      setState(() {
        _saving = false;
        _hasConflict = Future.value(true);
        _error = context.messages.goalRecordOfferConflict;
      });
      return;
    }
    final saved = await ref
        .read(goalMeasurableCaptureServiceProvider)
        .record(
          agentId: widget.agentId,
          agentName: widget.agentName,
          offer: widget.offer,
          items: selectedItems,
          private: widget.measurable.private ?? false,
          provenanceComment: context.messages.goalRecordOfferProvenance(
            widget.agentName,
          ),
        );
    if (!mounted) return;
    if (saved == null) {
      setState(() {
        _saving = false;
        _error = context.messages.measurementSaveError;
      });
      return;
    }
    ref.invalidate(goalMeasurableCaptureDecisionsProvider(widget.agentId));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = GoalAccentHues.aurora(Theme.of(context).brightness);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent.withValues(alpha: SurfaceAlphas.tint),
            border: Border.all(
              color: accent.withValues(alpha: SurfaceAlphas.washBorder),
            ),
            borderRadius: BorderRadius.circular(tokens.radii.l),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: accent),
                    SizedBox(width: tokens.spacing.step2),
                    Expanded(
                      child: Text(
                        context.messages.goalRecordOfferOverline(
                          widget.agentName.toUpperCase(),
                          widget.offer.measurableName.toUpperCase(),
                        ),
                        style: tokens.typography.styles.others.overline
                            .copyWith(
                              color: accent,
                            ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  context.messages.goalRecordOfferIntro,
                  style: tokens.typography.styles.body.bodyMedium,
                ),
                SizedBox(height: tokens.spacing.step3),
                for (var index = 0; index < _items.length; index++) ...[
                  _RecordOfferRow(
                    dayLabel: DateFormat.MMMEd(
                      locale,
                    ).format(_items[index].day),
                    unitName: widget.offer.unitName,
                    estimated: _items[index].estimated,
                    selected: _selected[index],
                    controller: _controllers[index],
                    onSelectionChanged: (selected) {
                      setState(() {
                        _selected[index] = selected;
                        _hasConflict = _loadConflict();
                        _error = null;
                      });
                    },
                  ),
                  if (index < _items.length - 1)
                    SizedBox(height: tokens.spacing.step2),
                ],
                FutureBuilder<bool>(
                  future: _hasConflict,
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step3),
                      child: Text(
                        context.messages.goalRecordOfferConflict,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: tokens.colors.alert.warning.ink,
                        ),
                      ),
                    );
                  },
                ),
                if (_error != null) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Text(
                    _error!,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.alert.error.ink,
                    ),
                  ),
                ],
                SizedBox(height: tokens.spacing.step4),
                FutureBuilder<bool>(
                  future: _hasConflict,
                  builder: (context, snapshot) => Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step2,
                    children: [
                      DesignSystemButton(
                        label: _items.length == 1
                            ? context.messages.goalRecordOfferRecordOne
                            : context.messages.goalRecordOfferRecordMany(
                                _selected.where((value) => value).length,
                              ),
                        onPressed:
                            snapshot.connectionState == ConnectionState.done &&
                                snapshot.data != true
                            ? _record
                            : null,
                        isLoading: _saving,
                        leadingIcon: Icons.edit_note_rounded,
                      ),
                      DesignSystemButton(
                        label:
                            context.messages.dailyOsOnboardingSpotlightDismiss,
                        onPressed: _saving ? null : _dismiss,
                        variant: DesignSystemButtonVariant.secondary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordOfferRow extends StatelessWidget {
  const _RecordOfferRow({
    required this.dayLabel,
    required this.unitName,
    required this.estimated,
    required this.selected,
    required this.controller,
    required this.onSelectionChanged,
  });

  final String dayLabel;
  final String unitName;
  final bool estimated;
  final bool selected;
  final TextEditingController controller;
  final ValueChanged<bool> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        IconButton(
          onPressed: () => onSelectionChanged(!selected),
          tooltip: selected
              ? context.messages.changeSetSwipeReject
              : context.messages.dailyOsNextRefineAccept,
          icon: Icon(
            selected ? Icons.check_circle_rounded : Icons.cancel_outlined,
            color: selected
                ? tokens.colors.alert.success.defaultColor
                : tokens.colors.text.lowEmphasis,
          ),
        ),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dayLabel,
                style: tokens.typography.styles.subtitle.subtitle2,
              ),
              if (estimated)
                Text(
                  context.messages.goalRecordOfferEstimatedSplit,
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        SizedBox(
          width: tokens.spacing.step13,
          child: DesignSystemTextInput(
            controller: controller,
            enabled: selected,
            size: DesignSystemTextInputSize.small,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            label: unitName,
          ),
        ),
      ],
    );
  }
}

class GoalRecordReceipt extends StatelessWidget {
  const GoalRecordReceipt({
    required this.entryCount,
    required this.agentName,
    super.key,
  });

  final int entryCount;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.alert.success.defaultColor.withValues(
            alpha: SurfaceAlphas.tint,
          ),
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step3,
            vertical: tokens.spacing.step2,
          ),
          child: Text(
            context.messages.goalRecordOfferReceipt(entryCount, agentName),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.alert.success.ink,
            ),
          ),
        ),
      ),
    );
  }
}
