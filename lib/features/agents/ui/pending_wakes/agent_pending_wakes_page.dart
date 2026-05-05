import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/pending_wake_record.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_date_format.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_listing_shell.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_row.dart'
    show monoMetaStyle;
import 'package:lotti/features/agents/ui/pending_wakes/pending_wake_view_model.dart';
import 'package:lotti/features/agents/ui/pending_wakes/wake_countdown_ticker.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

const String _typeAxisId = 'type';
const String _groupNone = 'all';
const String _groupByType = 'type';
const String _sortDueSoonest = 'dueSoonest';
const String _sortDueLatest = 'dueLatest';
const String _sortName = 'name';

/// Settings → Agents → Pending Wakes page. Adapts the wake VMs into the
/// shared [AgentListingShell] with a page-scoped 1Hz ticker so 1K rows
/// don't each spawn their own `Timer`.
class AgentPendingWakesPage extends ConsumerWidget {
  const AgentPendingWakesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    final asyncVms = ref.watch(agentPendingWakeRowVmsProvider);

    final adapted = asyncVms.whenData(
      (vms) => _AdaptedRows.from(vms, messages),
    );

    return AgentListingShell(
      rowsAsync: adapted.whenData((a) => a.rows),
      filterAxes: _buildFilterAxes(adapted, messages),
      groupAxes: _buildGroupAxes(messages, adapted),
      sortAxes: _buildSortAxes(messages),
      searchPlaceholder: messages.agentPendingWakesSearchPlaceholder,
      emptyMessage: messages.agentPendingWakesEmptyFiltered,
      axisMatcher: (axisId, selected, row) =>
          _matchRow(adapted, row, axisId, selected),
    );
  }
}

/// Adapter output: row list + per-id hint with the typed wake fields so
/// the matcher / group axes don't have to decode localized labels.
class _AdaptedRows {
  const _AdaptedRows({required this.rows, required this.hints});

  factory _AdaptedRows.from(
    List<PendingWakeVm> vms,
    AppLocalizations messages,
  ) {
    final rows = <AgentListRowData>[];
    final hints = <String, _RowHint>{};
    for (final vm in vms) {
      rows.add(_vmToRow(vm, messages));
      hints[vm.id] = _RowHint(type: vm.type, agentId: vm.agentId);
    }
    return _AdaptedRows(rows: rows, hints: hints);
  }

  final List<AgentListRowData> rows;
  final Map<String, _RowHint> hints;
}

class _RowHint {
  const _RowHint({required this.type, required this.agentId});
  final PendingWakeType type;
  final String agentId;
}

AgentListRowData _vmToRow(PendingWakeVm vm, AppLocalizations messages) {
  return AgentListRowData(
    id: vm.id,
    title: vm.title,
    subtitle: vm.subtitle,
    leading: AgentListIconLeading(
      icon: _wakeIcon(vm.type),
    ),
    pills: [
      AgentListPill(
        label: pendingWakeKindLabel(messages, vm.kind),
        tone: AgentListPillTone.interactive,
      ),
      AgentListPill(
        label: pendingWakeTypeLabel(messages, vm.type),
        tone: vm.type == PendingWakeType.pending
            ? AgentListPillTone.warning
            : AgentListPillTone.info,
      ),
    ],
    // No `metaRight`: the absolute due timestamp would duplicate the
    // live countdown in the trailing slot and force the second row
    // (in the compact layout) to overflow on phone-wide windows. The
    // exact timestamp surfaces as the countdown chip's tooltip.
    trailing: (context) => _PendingWakeTrailing(
      rowId: vm.id,
      dueAt: vm.dueAt,
      type: vm.type,
      agentId: vm.agentId,
    ),
    onTap: () => beamToNamed('/settings/agents/instances/${vm.agentId}'),
    sortAt: vm.dueAt,
    // Include the localized kind/type labels so users can search for
    // "Task Agent" or "Pending" as they appear in the row pills, not
    // just the raw enum / `AgentKinds` constants.
    searchKey:
        '${vm.title} ${vm.subtitle ?? ''} ${vm.agentId} ${vm.kind} '
                '${pendingWakeKindLabel(messages, vm.kind)} '
                '${pendingWakeTypeLabel(messages, vm.type)}'
            .toLowerCase(),
  );
}

IconData _wakeIcon(PendingWakeType type) {
  return switch (type) {
    PendingWakeType.pending => Icons.hourglass_bottom_rounded,
    PendingWakeType.scheduled => Icons.alarm_rounded,
  };
}

// ── Trailing ────────────────────────────────────────────────────────────────

/// Trailing slot for a pending-wake row: the live countdown (mono cell
/// fed by [wakeCountdownTickerProvider]) plus the delete affordance.
/// The delete state is local because it's per-row; the timer is not.
class _PendingWakeTrailing extends ConsumerStatefulWidget {
  const _PendingWakeTrailing({
    required this.rowId,
    required this.dueAt,
    required this.type,
    required this.agentId,
  });

  final String rowId;
  final DateTime dueAt;
  final PendingWakeType type;
  final String agentId;

  @override
  ConsumerState<_PendingWakeTrailing> createState() =>
      _PendingWakeTrailingState();
}

class _PendingWakeTrailingState extends ConsumerState<_PendingWakeTrailing> {
  bool _isDeleting = false;

  Future<void> _delete() async {
    setState(() => _isDeleting = true);
    final service = ref.read(agentServiceProvider);
    try {
      switch (widget.type) {
        case PendingWakeType.pending:
          service.cancelPendingWake(widget.agentId);
        case PendingWakeType.scheduled:
          await service.clearScheduledWake(widget.agentId);
      }
    } catch (_) {
      if (!mounted) return;
      // Skip the toast when no Scaffold is in scope: ScaffoldMessenger.
      // showSnackBar asserts on `_scaffolds.isNotEmpty`, so checking the
      // messenger alone isn't enough — the surrounding MaterialApp always
      // has a messenger even when no Scaffold is mounted.
      if (Scaffold.maybeOf(context) == null) return;
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.commonError,
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    // Using `select` here means this widget only rebuilds when the
    // visible countdown string changes — i.e. once a second per row
    // when due, never when other parts of the tick stream tick over.
    final countdown = ref.watch(
      wakeCountdownTickerProvider.select((async) {
        final now = async.value;
        if (now == null) return '…';
        return formatWakeCountdown(widget.dueAt, now);
      }),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: formatAgentDateTime(widget.dueAt),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step1,
            ),
            decoration: BoxDecoration(
              color: colors.surface.enabled,
              borderRadius: BorderRadius.circular(tokens.radii.xs),
            ),
            child: Text(
              countdown,
              // Build on the shared mono cell so the countdown chip
              // matches the row's other mono cells (id, time). Override
              // colour + tabular figures so digits don't jiggle as they
              // tick. A proper mono token in the design system would
              // remove the local font family override; tracked separately.
              style: monoMetaStyle(tokens, colors).copyWith(
                color: colors.text.highEmphasis,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        if (_isDeleting)
          SizedBox(
            width: tokens.spacing.step5,
            height: tokens.spacing.step5,
            child: const CircularProgressIndicator(strokeWidth: 2),
          )
        else
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            iconSize: 16,
            onPressed: _delete,
            tooltip: context.messages.agentPendingWakesDeleteTooltip,
            icon: Icon(
              Icons.delete_outline_rounded,
              color: colors.text.mediumEmphasis,
            ),
          ),
      ],
    );
  }
}

// ── Axes ────────────────────────────────────────────────────────────────────

List<AgentListFilterAxis> _buildFilterAxes(
  AsyncValue<_AdaptedRows> adapted,
  AppLocalizations messages,
) {
  final hints = adapted.maybeWhen(
    data: (a) => a.hints,
    orElse: () => const <String, _RowHint>{},
  );
  final counts = <PendingWakeType, int>{
    for (final t in PendingWakeType.values) t: 0,
  };
  for (final hint in hints.values) {
    counts[hint.type] = (counts[hint.type] ?? 0) + 1;
  }
  final present = counts.entries.where((e) => e.value > 0).toList();
  if (present.length < 2) return const [];
  return [
    AgentListFilterAxis(
      id: _typeAxisId,
      sectionLabel: messages.agentPendingWakesFilterSectionType,
      chipTone: AgentListPillTone.warning,
      options: [
        for (final t in PendingWakeType.values)
          AgentListFilterOption(
            id: t.name,
            label: pendingWakeTypeLabel(messages, t),
            count: counts[t] ?? 0,
          ),
      ],
    ),
  ];
}

List<AgentListGroupAxis> _buildGroupAxes(
  AppLocalizations messages,
  AsyncValue<_AdaptedRows> adapted,
) {
  Map<String, _RowHint> hintsOf() => adapted.maybeWhen(
    data: (a) => a.hints,
    orElse: () => const <String, _RowHint>{},
  );
  return [
    AgentListGroupAxis(
      id: _groupNone,
      label: messages.agentTemplatesGroupNone,
      // Group header is shown above the rows; reuse the axis label so
      // the visible string is the localized "All" rather than a literal.
      buildGroups: (rows) => rows.isEmpty
          ? const []
          : [
              AgentListGroup(
                id: 'all',
                label: messages.agentTemplatesGroupNone,
                items: rows,
              ),
            ],
    ),
    AgentListGroupAxis(
      id: _groupByType,
      label: messages.agentPendingWakesGroupByType,
      buildGroups: (rows) => _groupByTypeFn(rows, hintsOf(), messages),
    ),
  ];
}

List<AgentListSortAxis> _buildSortAxes(AppLocalizations messages) {
  return [
    AgentListSortAxis(
      id: _sortDueSoonest,
      label: messages.agentPendingWakesSortDueSoonest,
      compare: (a, b) {
        final byTime = a.sortAt.compareTo(b.sortAt);
        if (byTime != 0) return byTime;
        return a.id.compareTo(b.id);
      },
    ),
    AgentListSortAxis(
      id: _sortDueLatest,
      label: messages.agentPendingWakesSortDueLatest,
      compare: (a, b) => b.sortAt.compareTo(a.sortAt),
    ),
    AgentListSortAxis(
      id: _sortName,
      label: messages.agentInstancesSortName,
      compare: (a, b) {
        final byName = a.title.toLowerCase().compareTo(b.title.toLowerCase());
        if (byName != 0) return byName;
        return a.id.compareTo(b.id);
      },
    ),
  ];
}

// ── Group builders ──────────────────────────────────────────────────────────

List<AgentListGroup> _groupByTypeFn(
  List<AgentListRowData> rows,
  Map<String, _RowHint> hints,
  AppLocalizations messages,
) {
  final buckets = <PendingWakeType, List<AgentListRowData>>{};
  for (final row in rows) {
    final type = hints[row.id]?.type ?? PendingWakeType.pending;
    buckets.putIfAbsent(type, () => []).add(row);
  }
  // Stable order: pending first (typical operator focus), scheduled second.
  return [
    for (final t in PendingWakeType.values)
      if (buckets[t] != null)
        AgentListGroup(
          id: 'type:${t.name}',
          label: pendingWakeTypeLabel(messages, t),
          items: buckets[t]!,
        ),
  ];
}

// ── Axis matcher ────────────────────────────────────────────────────────────

bool _matchRow(
  AsyncValue<_AdaptedRows> adapted,
  AgentListRowData row,
  String axisId,
  Set<String> selected,
) {
  final hints = adapted.maybeWhen(
    data: (a) => a.hints,
    orElse: () => const <String, _RowHint>{},
  );
  final hint = hints[row.id];
  if (hint == null) return true;
  return switch (axisId) {
    _typeAxisId => selected.contains(hint.type.name),
    _ => true,
  };
}
