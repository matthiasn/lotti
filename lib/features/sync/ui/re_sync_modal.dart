import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/progress_bars/design_system_progress_bar.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/services/historical_sync_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Historical interval choices offered by [ReSyncModalContent].
enum ReSyncRangePreset {
  everything,
  last30Days,
  custom,
}

/// Inclusive lower sentinel used by the All preset.
final DateTime reSyncEverythingStart = DateTime.utc(1);

class ReSyncModalContent extends ConsumerStatefulWidget {
  const ReSyncModalContent({
    super.key,
    this.onboardingTarget,
    this.onboardingSyncService,
    this.onOnboardingPreflightHandled,
    this.onOnboardingRoundChanged,
  });

  final OnboardingSyncTarget? onboardingTarget;
  final OnboardingSyncService? onboardingSyncService;
  final VoidCallback? onOnboardingPreflightHandled;
  final ValueChanged<OutboundOnboardingRound?>? onOnboardingRoundChanged;

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
  ReSyncResult? _result;
  OutboundOnboardingRound? _activeOnboardingRound;

  @override
  void initState() {
    super.initState();
    final today = clock.now().dateOnly;
    _dateFrom = today.subtract(const Duration(days: 30));
    _dateTo = today;
  }

  bool get _hasEntitySelection =>
      _includeJournalEntities || _includeAgentEntities;

  bool get _hasValidCustomRange => !_dateFrom.isAfter(_dateTo);

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

  bool get _isFullOnboarding =>
      widget.onboardingTarget != null &&
      _rangePreset == ReSyncRangePreset.everything &&
      _includeJournalEntities &&
      _includeAgentEntities;

  OnboardingSyncService get _onboardingService =>
      widget.onboardingSyncService ?? getIt<OnboardingSyncService>();

  Future<void> _start() async {
    if (!_canStart) return;

    final now = clock.now();
    final (start, end) = switch (_rangePreset) {
      ReSyncRangePreset.everything => (reSyncEverythingStart, now),
      ReSyncRangePreset.last30Days => (
        now.subtract(const Duration(days: 30)),
        now,
      ),
      // The calendar presents an inclusive date range, while the database
      // query uses an exclusive upper bound.
      ReSyncRangePreset.custom => (_dateFrom, _dateTo.addCalendarDays(1)),
    };

    setState(() {
      _isRunning = true;
      _failed = false;
      _progress = const {};
      _result = null;
    });

    OutboundOnboardingRound? onboardingRound;
    try {
      if (_isFullOnboarding) {
        onboardingRound = await _onboardingService.beginOutbound(
          widget.onboardingTarget!,
        );
        _setActiveOnboardingRound(onboardingRound);
        widget.onOnboardingPreflightHandled?.call();
      } else if (widget.onboardingTarget case final target?) {
        await _onboardingService.releaseInboundPreflight(target);
        widget.onOnboardingPreflightHandled?.call();
      }
      final result = await ref
          .read(historicalSyncServiceProvider)
          .reSyncInterval(
            start: start,
            end: end,
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
      if (onboardingRound != null && !result.hasFailures) {
        await _onboardingService.completeOutbound(onboardingRound);
        _setActiveOnboardingRound(null);
      }
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isComplete = true;
        _result = result;
      });
    } catch (error, stackTrace) {
      await _abortOnboardingAndLog(
        error,
        stackTrace,
        abortSubDomain: 'reSyncOnboardingAbort',
        errorSubDomain: 'reSyncMessages',
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _failed = true;
      });
    }
  }

  void _setActiveOnboardingRound(OutboundOnboardingRound? round) {
    _activeOnboardingRound = round;
    widget.onOnboardingRoundChanged?.call(round);
  }

  Future<void> _abortOnboardingAndLog(
    Object error,
    StackTrace stackTrace, {
    required String abortSubDomain,
    required String errorSubDomain,
  }) async {
    final onboardingRound = _activeOnboardingRound;
    if (onboardingRound != null) {
      try {
        await _onboardingService.abortOutbound(onboardingRound);
        _setActiveOnboardingRound(null);
      } catch (abortError, abortStackTrace) {
        getIt<DomainLogger>().error(
          LogDomain.sync,
          abortError,
          stackTrace: abortStackTrace,
          subDomain: abortSubDomain,
        );
      }
    }
    getIt<DomainLogger>().error(
      LogDomain.sync,
      error,
      stackTrace: stackTrace,
      subDomain: errorSubDomain,
    );
  }

  Future<void> _retryFailures() async {
    final previous = _result;
    if (previous == null || !previous.hasFailures || _isRunning) return;

    setState(() {
      _isRunning = true;
      _isComplete = false;
      _failed = false;
      _progress = const {};
    });

    try {
      final result = await previous.retryFailures(
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _progress = {..._progress, progress.phase: progress};
          });
        },
      );
      if (!mounted) return;
      final onboardingRound = _activeOnboardingRound;
      if (!result.hasFailures && onboardingRound != null) {
        await _onboardingService.completeOutbound(onboardingRound);
        _setActiveOnboardingRound(null);
      }
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isComplete = true;
        _result = result;
      });
    } catch (error, stackTrace) {
      await _abortOnboardingAndLog(
        error,
        stackTrace,
        abortSubDomain: 'reSyncOnboardingRetryAbort',
        errorSubDomain: 'reSyncMessagesRetry',
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isComplete = false;
        _failed = true;
      });
    }
  }

  Future<void> _pickCustomDate({required bool start}) async {
    final messages = context.messages;
    final result = await showDesignSystemDatePicker(
      context: context,
      title: start
          ? messages.settingsHealthImportFromDate
          : messages.settingsHealthImportToDate,
      initialDate: start ? _dateFrom : _dateTo,
      firstDate: DateTime(1),
      lastDate: clock.now().dateOnly,
    );
    final selected = result?.date;
    if (!mounted || selected == null) return;
    setState(() {
      if (start) {
        _dateFrom = selected;
      } else {
        _dateTo = selected;
      }
      _failed = false;
    });
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
          DesignSystemPickerSection(
            child: Column(
              children: [
                _ReSyncDateRow(
                  key: const Key('reSyncStartDate'),
                  label: messages.settingsHealthImportFromDate,
                  date: _dateFrom,
                  onTap: () => unawaited(_pickCustomDate(start: true)),
                  showDivider: true,
                ),
                _ReSyncDateRow(
                  key: const Key('reSyncEndDate'),
                  label: messages.settingsHealthImportToDate,
                  date: _dateTo,
                  onTap: () => unawaited(_pickCustomDate(start: false)),
                ),
              ],
            ),
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
        DesignSystemSelectionRow(
          key: const Key('reSyncJournalEntitiesCheckbox'),
          title: messages.maintenanceReSyncJournalEntities,
          type: DesignSystemSelectionRowType.multiSelect,
          size: DesignSystemListItemSize.small,
          selected: _includeJournalEntities,
          showSelectedBackground: false,
          onTap: () {
            setState(() {
              _includeJournalEntities = !_includeJournalEntities;
              _failed = false;
            });
          },
        ),
        DesignSystemSelectionRow(
          key: const Key('reSyncAgentEntitiesCheckbox'),
          title: messages.maintenanceReSyncAgentEntities,
          type: DesignSystemSelectionRowType.multiSelect,
          size: DesignSystemListItemSize.small,
          selected: _includeAgentEntities,
          showSelectedBackground: false,
          onTap: () {
            setState(() {
              _includeAgentEntities = !_includeAgentEntities;
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
    final result = _result ?? ReSyncResult.empty;
    final hasFailures = result.hasFailures;

    return Column(
      key: const Key('reSyncComplete'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          hasFailures ? LottiIcons.warning : LottiIcons.confirmCircled,
          size: IconSizes.xxxl,
          color: hasFailures
              ? tokens.colors.alert.warning.defaultColor
              : tokens.colors.alert.success.defaultColor,
        ),
        SizedBox(height: tokens.spacing.step5),
        Text(
          hasFailures
              ? messages.maintenanceReSyncPartialTitle(
                  result.succeeded,
                  result.total,
                )
              : messages.maintenanceReSyncCompleteTitle,
          style: tokens.typography.styles.subtitle.subtitle1,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: tokens.spacing.step3),
        Text(
          hasFailures
              ? messages.maintenanceReSyncPartialDescription(
                  result.failures.length,
                )
              : messages.maintenanceReSyncCompleteDescription,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
        if (hasFailures) ...[
          SizedBox(height: tokens.spacing.step5),
          DesignSystemInlineCallout(
            key: const Key('reSyncFailureDetails'),
            icon: LottiIcons.error,
            text: result.failures
                .map(
                  (failure) =>
                      '${_failureTypeLabel(messages, failure.itemType)}: '
                      '${failure.itemId}',
                )
                .join('\n'),
          ),
          SizedBox(height: tokens.spacing.step6),
          DesignSystemButton(
            key: const Key('reSyncRetryFailures'),
            label: messages.maintenanceReSyncRetryFailed,
            size: DesignSystemButtonSize.large,
            leadingIcon: LottiIcons.refresh,
            fullWidth: true,
            onPressed: () => unawaited(_retryFailures()),
          ),
        ],
        SizedBox(height: tokens.spacing.step6),
        DesignSystemButton(
          label: messages.doneButton,
          variant: hasFailures
              ? DesignSystemButtonVariant.secondary
              : DesignSystemButtonVariant.primary,
          size: DesignSystemButtonSize.large,
          leadingIcon: LottiIcons.confirmCircled,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  String _failureTypeLabel(
    AppLocalizations messages,
    ReSyncItemType itemType,
  ) => switch (itemType) {
    ReSyncItemType.journalEntity => messages.syncPayloadJournalEntity,
    ReSyncItemType.entryLink => messages.syncPayloadEntryLink,
    ReSyncItemType.agentEntity => messages.syncPayloadAgentEntity,
    ReSyncItemType.agentLink => messages.syncPayloadAgentLink,
  };
}

class _ReSyncDateRow extends StatelessWidget {
  const _ReSyncDateRow({
    required this.label,
    required this.date,
    required this.onTap,
    this.showDivider = false,
    super.key,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return DesignSystemListItem(
      title: label,
      subtitle: DateFormat.yMMMd(locale).format(date),
      trailing: Icon(
        LottiIcons.calendar,
        size: IconSizes.m,
        color: tokens.colors.text.mediumEmphasis,
      ),
      showDivider: showDivider,
      onTap: onTap,
      semanticsLabel: '$label, ${DateFormat.yMMMMd(locale).format(date)}',
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
    final hasFailures = (progress?.failed ?? 0) > 0;
    final label = switch (phase) {
      ReSyncPhase.journalEntities =>
        context.messages.maintenanceReSyncJournalEntities,
      ReSyncPhase.agentEntities =>
        context.messages.maintenanceReSyncAgentEntities,
      ReSyncPhase.agentLinks => context.messages.maintenanceReSyncAgentLinks,
    };
    final processed = progress?.succeeded ?? 0;
    final total = progress?.total;
    final count = total == null ? '$processed' : '$processed / $total';

    return Row(
      children: [
        if (isComplete && !hasFailures)
          Icon(
            LottiIcons.confirmCircled,
            size: IconSizes.s,
            color: tokens.colors.alert.success.defaultColor,
          )
        else if (isComplete)
          Icon(
            LottiIcons.warning,
            size: IconSizes.s,
            color: tokens.colors.alert.warning.defaultColor,
          )
        else if (progress != null)
          const DesignSystemSpinner(
            size: IconSizes.s,
            strokeWidth: BorderWidths.emphasis,
          )
        else
          Icon(
            LottiIcons.radioUnselected,
            size: IconSizes.s,
            color: tokens.colors.text.lowEmphasis,
          ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: isComplete && !hasFailures
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
  static Future<void> show(
    BuildContext context, {
    OnboardingSyncTarget? onboardingTarget,
    OnboardingSyncService? onboardingSyncService,
  }) async {
    var preflightHandled = onboardingTarget == null;
    OutboundOnboardingRound? activeRound;
    OnboardingSyncService resolveService() =>
        onboardingSyncService ?? getIt<OnboardingSyncService>();
    try {
      await ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.maintenanceReSync,
        builder: (_) => ReSyncModalContent(
          onboardingTarget: onboardingTarget,
          onboardingSyncService: onboardingSyncService,
          onOnboardingPreflightHandled: () => preflightHandled = true,
          onOnboardingRoundChanged: (round) => activeRound = round,
        ),
      );
    } finally {
      if (activeRound case final round?) {
        try {
          await resolveService().abortOutbound(round);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'reSyncOnboardingDismissAbort',
          );
        }
      } else if (!preflightHandled && onboardingTarget != null) {
        try {
          await resolveService().releaseInboundPreflight(onboardingTarget);
        } catch (error, stackTrace) {
          getIt<DomainLogger>().error(
            LogDomain.sync,
            error,
            stackTrace: stackTrace,
            subDomain: 'reSyncOnboardingRelease',
          );
        }
      }
    }
  }
}
