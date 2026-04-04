import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_pending_wake_providers.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_badge_widgets.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

class AgentPendingWakesList extends ConsumerWidget {
  const AgentPendingWakesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wakesAsync = ref.watch(pendingWakeRecordsProvider);
    final tokens = context.designTokens;

    final records = wakesAsync.value;

    if (wakesAsync.isLoading && records == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (wakesAsync.hasError && records == null) {
      return Center(
        child: Text(
          context.messages.commonError,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.error,
          ),
        ),
      );
    }

    if (records == null || records.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.alarm_off_rounded,
              size: tokens.spacing.step12,
              color: context.colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: tokens.spacing.step4),
            Text(
              context.messages.agentPendingWakesEmptyList,
              style: context.textTheme.titleMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (wakesAsync.hasError)
          Material(
            color: context.colorScheme.errorContainer,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step4,
                vertical: tokens.spacing.step2,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: context.colorScheme.onErrorContainer,
                  ),
                  SizedBox(width: tokens.spacing.step2),
                  Expanded(
                    child: Text(
                      context.messages.commonError,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const WakeActivityChart(),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step4,
              0,
              tokens.spacing.step4,
              tokens.spacing.step6,
            ),
            itemCount: records.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                child: _PendingWakeCard(
                  key: ValueKey(records[index].id),
                  record: records[index],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PendingWakeCard extends ConsumerStatefulWidget {
  const _PendingWakeCard({
    required this.record,
    super.key,
  });

  final PendingWakeRecord record;

  @override
  ConsumerState<_PendingWakeCard> createState() => _PendingWakeCardState();
}

class _PendingWakeCardState extends ConsumerState<_PendingWakeCard> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(covariant _PendingWakeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.dueAt != widget.record.dueAt) {
      _startCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    _remainingSeconds = _remainingFromDueAt(widget.record.dueAt);

    if (_remainingSeconds <= 0) {
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final remainingSeconds = _remainingFromDueAt(widget.record.dueAt);
      setState(() {
        _remainingSeconds = remainingSeconds;
        if (_remainingSeconds <= 0) {
          timer.cancel();
        }
      });
    });
  }

  int _remainingFromDueAt(DateTime dueAt) {
    final remaining = dueAt.difference(clock.now());
    if (remaining <= Duration.zero) {
      return 0;
    }
    return remaining.inSeconds;
  }

  Future<void> _deleteWake() async {
    setState(() => _isDeleting = true);
    final service = ref.read(agentServiceProvider);

    try {
      switch (widget.record.type) {
        case PendingWakeType.pending:
          service.cancelPendingWake(widget.record.agent.agentId);
        case PendingWakeType.scheduled:
          await service.clearScheduledWake(widget.record.agent.agentId);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      final scaffold = Scaffold.maybeOf(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (scaffold != null && messenger != null) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.messages.commonError),
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final record = widget.record;
    final subjectTitleAsync = ref.watch(
      pendingWakeTargetTitleProvider(_subjectEntryId(record)),
    );
    final resolvedSubjectTitle = subjectTitleAsync.value;
    final hasSubjectTitle =
        resolvedSubjectTitle?.trim().isNotEmpty == true &&
        resolvedSubjectTitle != record.agent.displayName;

    return ModernBaseCard(
      onTap: () =>
          beamToNamed('/settings/agents/instances/${record.agent.agentId}'),
      padding: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: tokens.spacing.step9,
              height: tokens.spacing.step9,
              decoration: BoxDecoration(
                color: _wakeAccentColor(context, record.type).withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(tokens.radii.s),
              ),
              child: Icon(
                _wakeIcon(record.type),
                color: _wakeAccentColor(context, record.type),
                size: tokens.typography.lineHeight.subtitle1,
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (hasSubjectTitle)
                              Text(
                                resolvedSubjectTitle!,
                                style: context.textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              record.agent.displayName,
                              style: hasSubjectTitle
                                  ? context.textTheme.bodySmall?.copyWith(
                                      color:
                                          context.colorScheme.onSurfaceVariant,
                                    )
                                  : context.textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      if (_isDeleting)
                        SizedBox(
                          width: tokens.spacing.step5,
                          height: tokens.spacing.step5,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: _deleteWake,
                          tooltip:
                              context.messages.agentPendingWakesDeleteTooltip,
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step1 / 2),
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step1,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      AgentBadge(
                        label: _kindLabel(context, record.agent.kind),
                        color: context.colorScheme.primary,
                      ),
                      AgentLifecycleBadge(
                        lifecycle: record.agent.lifecycle,
                      ),
                      AgentBadge(
                        label: _wakeTypeLabel(context, record.type),
                        color: _wakeAccentColor(context, record.type),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  Row(
                    children: [
                      Flexible(
                        child: _WakeMetaChip(
                          icon: Icons.schedule_rounded,
                          tooltip: context.messages.agentPendingWakesDueAtLabel,
                          value: formatAgentDateTime(record.dueAt),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Flexible(
                        child: _WakeMetaChip(
                          icon: Icons.timer_outlined,
                          tooltip:
                              context.messages.agentPendingWakesCountdownLabel,
                          value: _formatCountdown(_remainingSeconds),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _wakeIcon(PendingWakeType type) {
    return switch (type) {
      PendingWakeType.pending => Icons.hourglass_bottom_rounded,
      PendingWakeType.scheduled => Icons.alarm_rounded,
    };
  }

  Color _wakeAccentColor(BuildContext context, PendingWakeType type) {
    return switch (type) {
      PendingWakeType.pending => context.colorScheme.tertiary,
      PendingWakeType.scheduled => context.colorScheme.secondary,
    };
  }

  String _wakeTypeLabel(BuildContext context, PendingWakeType type) {
    return switch (type) {
      PendingWakeType.pending => context.messages.agentPendingWakesPendingLabel,
      PendingWakeType.scheduled =>
        context.messages.agentPendingWakesScheduledLabel,
    };
  }

  String _kindLabel(BuildContext context, String kind) {
    return switch (kind) {
      AgentKinds.taskAgent => context.messages.agentInstancesKindTaskAgent,
      AgentKinds.projectAgent => context.messages.agentTemplateKindProjectAgent,
      AgentKinds.templateImprover => context.messages.agentTemplateKindImprover,
      _ => kind,
    };
  }

  String _formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) {
      return '0s';
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final parts = <String>[];

    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || hours > 0) {
      parts.add('${minutes}m');
    }
    parts.add('${seconds}s');
    return parts.join(' ');
  }
}

class _WakeMetaChip extends StatelessWidget {
  const _WakeMetaChip({
    required this.icon,
    required this.tooltip,
    required this.value,
  });

  final IconData icon;
  final String tooltip;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final valueStyle = context.textTheme.bodySmall?.copyWith(
      color: context.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step1 + (tokens.spacing.step1 / 2),
      ),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Tooltip(
        message: tooltip,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: tokens.typography.size.subtitle2,
              color: context.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.88,
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
            Flexible(
              child: Text(
                value,
                style: valueStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _subjectEntryId(PendingWakeRecord record) {
  return record.state.slots.activeTaskId ?? record.state.slots.activeProjectId;
}
