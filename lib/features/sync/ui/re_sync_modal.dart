import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/maintenance.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Historical interval choices offered by [ReSyncModalContent].
enum ReSyncRangePreset {
  everything,
  last30Days,
  custom,
}

/// Inclusive lower sentinel used by the Everything preset.
final DateTime reSyncEverythingStart = DateTime.utc(1);

class ReSyncModalContent extends ConsumerStatefulWidget {
  const ReSyncModalContent({super.key});

  @override
  ConsumerState<ReSyncModalContent> createState() => _ReSyncModalContentState();
}

class _ReSyncModalContentState extends ConsumerState<ReSyncModalContent> {
  late DateTime _dateFrom;
  late DateTime _dateTo;
  ReSyncRangePreset _rangePreset = ReSyncRangePreset.everything;
  bool _includeJournalEntities = true;
  bool _includeAgentEntities = true;
  bool _isRunning = false;
  bool _isComplete = false;
  bool _failed = false;
  Map<ReSyncPhase, ReSyncProgress> _progress = const {};

  @override
  void initState() {
    super.initState();
    final now = clock.now();
    _dateFrom = now.subtract(const Duration(days: 30));
    _dateTo = now;
  }

  bool get _hasEntitySelection =>
      _includeJournalEntities || _includeAgentEntities;

  bool get _hasValidCustomRange => _dateFrom.isBefore(_dateTo);

  bool get _canStart =>
      !_isRunning &&
      _hasEntitySelection &&
      (_rangePreset != ReSyncRangePreset.custom || _hasValidCustomRange);

  List<ReSyncPhase> get _selectedPhases => [
    if (_includeJournalEntities) ReSyncPhase.journalEntities,
    if (_includeAgentEntities) ...[
      ReSyncPhase.agentEntities,
      ReSyncPhase.agentLinks,
    ],
  ];

  Future<void> _start() async {
    if (!_canStart) return;

    final now = clock.now();
    final (start, end) = switch (_rangePreset) {
      ReSyncRangePreset.everything => (reSyncEverythingStart, now),
      ReSyncRangePreset.last30Days => (
        now.subtract(const Duration(days: 30)),
        now,
      ),
      ReSyncRangePreset.custom => (_dateFrom, _dateTo),
    };

    setState(() {
      _isRunning = true;
      _failed = false;
      _progress = const {};
    });

    try {
      await ref
          .read(maintenanceProvider)
          .reSyncInterval(
            start: start,
            end: end,
            agentRepository: ref.read(agentRepositoryProvider),
            includeJournalEntities: _includeJournalEntities,
            includeAgentEntities: _includeAgentEntities,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() {
                _progress = {..._progress, progress.phase: progress};
              });
            },
          );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isComplete = true;
      });
    } catch (error, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'reSyncMessages',
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.all(tokens.spacing.step7),
      child: switch ((_isRunning, _isComplete)) {
        (_, true) => _buildComplete(context),
        (true, false) => _buildProgress(context),
        (false, false) => _buildForm(context),
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSegmentedToggle<ReSyncRangePreset>(
          key: const Key('reSyncRangePreset'),
          segments: [
            DsSegment(
              ReSyncRangePreset.everything,
              messages.maintenanceReSyncEverything,
            ),
            DsSegment(
              ReSyncRangePreset.last30Days,
              messages.maintenanceReSyncLast30Days,
            ),
            DsSegment(
              ReSyncRangePreset.custom,
              messages.maintenanceReSyncCustom,
            ),
          ],
          selected: _rangePreset,
          expand: true,
          onChanged: (preset) {
            setState(() {
              _rangePreset = preset;
              _failed = false;
            });
          },
        ),
        if (_rangePreset == ReSyncRangePreset.custom) ...[
          SizedBox(height: tokens.spacing.step6),
          DateTimeField(
            dateTime: _dateFrom,
            labelText: messages.settingsHealthImportFromDate,
            setDateTime: (value) {
              setState(() {
                _dateFrom = value;
                _failed = false;
              });
            },
          ),
          SizedBox(height: tokens.spacing.step5),
          DateTimeField(
            dateTime: _dateTo,
            labelText: messages.settingsHealthImportToDate,
            setDateTime: (value) {
              setState(() {
                _dateTo = value;
                _failed = false;
              });
            },
          ),
          if (!_hasValidCustomRange)
            Padding(
              key: const Key('reSyncInvalidRangeError'),
              padding: EdgeInsets.only(top: tokens.spacing.step2),
              child: Text(
                messages.maintenanceReSyncInvalidRange,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.alert.error.ink,
                ),
              ),
            ),
        ],
        SizedBox(height: tokens.spacing.step6),
        Text(
          messages.maintenanceReSyncEntityTypes,
          style: tokens.typography.styles.subtitle.subtitle2,
        ),
        SizedBox(height: tokens.spacing.step2),
        DesignSystemCheckbox(
          key: const Key('reSyncJournalEntitiesCheckbox'),
          label: messages.maintenanceReSyncJournalEntities,
          value: _includeJournalEntities,
          onChanged: (value) {
            setState(() {
              _includeJournalEntities = value ?? false;
              _failed = false;
            });
          },
        ),
        DesignSystemCheckbox(
          key: const Key('reSyncAgentEntitiesCheckbox'),
          label: messages.maintenanceReSyncAgentEntities,
          value: _includeAgentEntities,
          onChanged: (value) {
            setState(() {
              _includeAgentEntities = value ?? false;
              _failed = false;
            });
          },
        ),
        if (!_hasEntitySelection)
          Padding(
            key: const Key('reSyncSelectAtLeastOneError'),
            padding: EdgeInsets.only(
              top: tokens.spacing.step2,
              bottom: tokens.spacing.step4,
            ),
            child: Text(
              messages.maintenanceReSyncSelectAtLeastOne,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.ink,
              ),
            ),
          ),
        if (_failed)
          Padding(
            key: const Key('reSyncFailed'),
            padding: EdgeInsets.only(
              top: tokens.spacing.step2,
              bottom: tokens.spacing.step4,
            ),
            child: Text(
              messages.maintenanceReSyncFailed,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.error.ink,
              ),
            ),
          ),
        SizedBox(height: tokens.spacing.step6),
        DesignSystemButton(
          label: messages.maintenanceReSyncStart,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: _canStart ? () => unawaited(_start()) : null,
        ),
      ],
    );
  }

  Widget _buildProgress(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final phases = _selectedPhases;
    var completed = 0.0;
    for (final phase in phases) {
      final progress = _progress[phase];
      if (progress == null) continue;
      if (progress.isComplete) {
        completed += 1;
      } else if (progress.total != null && progress.total! > 0) {
        final total = progress.total!;
        completed += (progress.processed / total).clamp(0.0, 1.0);
      }
    }
    final value = phases.isEmpty
        ? 0.0
        : (completed / phases.length).clamp(0.0, 1.0);
    final percent = (value * 100).round();

    return Column(
      key: const Key('reSyncProgress'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemProgressBar(
          value: value,
          label: messages.maintenanceReSyncSending,
          progressText: '$percent%',
        ),
        SizedBox(height: tokens.spacing.step6),
        for (final phase in phases) ...[
          _ReSyncProgressRow(
            phase: phase,
            progress: _progress[phase],
          ),
          if (phase != phases.last) SizedBox(height: tokens.spacing.step4),
        ],
      ],
    );
  }

  Widget _buildComplete(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      key: const Key('reSyncComplete'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          size: IconSizes.xxxl,
          color: tokens.colors.alert.success.defaultColor,
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          messages.maintenanceReSyncCompleteTitle,
          style: tokens.typography.styles.subtitle.subtitle1,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          messages.maintenanceReSyncCompleteDescription,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step6),
        DesignSystemButton(
          label: messages.doneButton,
          size: DesignSystemButtonSize.large,
          leadingIcon: Icons.check_circle_rounded,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _ReSyncProgressRow extends StatelessWidget {
  const _ReSyncProgressRow({
    required this.phase,
    required this.progress,
  });

  final ReSyncPhase phase;
  final ReSyncProgress? progress;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isComplete = progress?.isComplete ?? false;
    final label = switch (phase) {
      ReSyncPhase.journalEntities =>
        context.messages.maintenanceReSyncJournalEntities,
      ReSyncPhase.agentEntities =>
        context.messages.maintenanceReSyncAgentEntities,
      ReSyncPhase.agentLinks => context.messages.maintenanceReSyncAgentLinks,
    };
    final processed = progress?.processed ?? 0;
    final total = progress?.total;
    final count = total == null ? '$processed' : '$processed / $total';

    return Row(
      children: [
        if (isComplete)
          Icon(
            Icons.check_circle_outline_rounded,
            size: IconSizes.s,
            color: tokens.colors.alert.success.defaultColor,
          )
        else if (progress != null)
          const DesignSystemSpinner(
            size: IconSizes.s,
            strokeWidth: BorderWidths.emphasis,
          )
        else
          Icon(
            Icons.circle_outlined,
            size: IconSizes.s,
            color: tokens.colors.text.lowEmphasis,
          ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: isComplete
                  ? tokens.colors.alert.success.ink
                  : tokens.colors.text.highEmphasis,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Text(
          count,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class ReSyncModal {
  static Future<void> show(BuildContext context) async {
    await ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.maintenanceReSync,
      builder: (_) => const ReSyncModalContent(),
    );
  }
}
