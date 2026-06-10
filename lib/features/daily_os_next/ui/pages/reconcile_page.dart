import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_thinking_shader.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/parsed_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/pending_card.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Width at/above which the reconcile surface lays the Heard / Decide
/// columns side by side; below it they stack. Shared by the page, the modal
/// content, and the footer so the breakpoint can't drift between them.
const double _reconcileTwoColumnBreakpoint = 720;

/// Flex weights for the side-by-side Heard / Decide columns — the Heard
/// column (parsed items) gets slightly more room than the Decide column.
const int _heardColumnFlex = 6;
const int _decideColumnFlex = 5;

/// Second screen of the agentic loop — turn the spoken check-in into
/// editable structure and fold in the existing corpus.
///
/// Mirrors `prototype/screens/reconcile.jsx`. Two-column on wide
/// surfaces, single-column on narrow.
class ReconcilePage extends ConsumerWidget {
  const ReconcilePage({
    required this.captureId,
    this.dayDate,
    super.key,
  });

  /// The capture submitted from the Capture screen. The controller
  /// uses it to fetch the parsed items.
  final CaptureId captureId;

  /// The local calendar day being planned. Defaults to today for
  /// direct preview/tests, but production capture flows pass the
  /// route-level selected date.
  final DateTime? dayDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final params = ReconcileParams(
      captureId: captureId,
      dayDate:
          dayDate ??
          DateTime(clock.now().year, clock.now().month, clock.now().day),
    );
    final state = ref.watch(reconcileControllerProvider(params));

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.messages.dailyOsNextReconcileReRecord,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: DesignSystemBottomNavigationBar.occupiedHeight(context),
          ),
          child: switch (state) {
            _ when state.hasValue => _ReconcileBody(
              params: params,
              data: state.requireValue,
            ),
            _ when state.hasError => Center(
              child: Text(
                context.messages.dailyOsNextGenericError,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _ReconcileBody extends ConsumerWidget {
  const _ReconcileBody({required this.params, required this.data});

  final ReconcileParams params;
  final ReconcileData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final isWide =
        MediaQuery.sizeOf(context).width >= _reconcileTwoColumnBreakpoint;

    final heardColumn = _HeardColumn(params: params, items: data.parsed);
    final decideColumn = _DecideColumn(
      params: params,
      items: data.pending,
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step6,
              vertical: tokens.spacing.step5,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: _heardColumnFlex, child: heardColumn),
                      SizedBox(width: tokens.spacing.step6),
                      Expanded(flex: _decideColumnFlex, child: decideColumn),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heardColumn,
                      SizedBox(height: tokens.spacing.step6),
                      decideColumn,
                    ],
                  ),
          ),
        ),
        _ReconcileFooter(params: params, data: data),
      ],
    );
  }
}

class _HeardColumn extends ConsumerWidget {
  const _HeardColumn({required this.params, required this.items});

  final ReconcileParams params;
  final List<ParsedItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    // While the capture-submitted parse wake is still running, the parsed
    // cards haven't landed yet — surface the AI thinking shader above the
    // empty placeholder so the column reads as "working", not "done/empty".
    final isParsing =
        ref
            .watch(agentIsRunningProvider(dayAgentIdForDate(params.dayDate)))
            .value ??
        false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          overline: context.messages.dailyOsNextReconcileHeardOverline,
          count: items.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        if (items.isEmpty) ...[
          if (isParsing) ...[
            const DayPlanningThinkingShader(isThinking: true),
            SizedBox(height: tokens.spacing.step3),
          ],
          DsDashedBorder(
            color: tokens.colors.decorative.level02,
            radius: tokens.radii.m,
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: Text(
                context.messages.dailyOsNextReconcileHeardEmpty,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
        for (final item in items) ...[
          ParsedCard(
            item: item,
            onBreakLink: () => ref
                .read(reconcileControllerProvider(params).notifier)
                .breakLink(item.id),
          ),
          SizedBox(height: tokens.spacing.step4),
        ],
      ],
    );
  }
}

class _DecideColumn extends ConsumerWidget {
  const _DecideColumn({required this.params, required this.items});

  final ReconcileParams params;
  final List<PendingItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final notifier = ref.read(reconcileControllerProvider(params).notifier);
    final decided = ref.watch(
      reconcileControllerProvider(params).select(
        (asyncValue) => asyncValue.hasValue
            ? asyncValue.requireValue.triageDecisions
            : const <String, TriageResult>{},
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          overline: context.messages.dailyOsNextReconcileDecideOverline,
          count: items.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        for (final item in items) ...[
          PendingCard(
            item: item,
            decision: decided[item.taskId],
            onTriage: (action) =>
                notifier.triage(taskId: item.taskId, action: action),
          ),
          SizedBox(height: tokens.spacing.step4),
        ],
        SizedBox(height: tokens.spacing.step3),
        const _DefaultBehaviorHint(),
      ],
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  const _ColumnHeader({required this.overline, required this.count});

  final String overline;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Expanded(
          child: Text(
            overline,
            style: calmEyebrowStyle(tokens),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.s),
          ),
          child: Text(
            '$count',
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ],
    );
  }
}

class _DefaultBehaviorHint extends StatelessWidget {
  const _DefaultBehaviorHint();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DsDashedBorder(
      color: tokens.colors.decorative.level02,
      radius: tokens.radii.m,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Text(
          context.messages.dailyOsNextReconcileDefaultBehaviorHint,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// The work the user has effectively committed to taking on for the day,
/// derived from a reconcile result — the inputs the drafting step needs.
///
/// Matched/update parsed items and pending triage rows carry task IDs.
/// NEW/unlinked parsed items carry parsed capture item IDs so drafting can
/// still create tasks from the approved capture text before placing them.
({List<String> taskIds, List<String> captureItemIds})
reconcileDraftingSelections(ReconcileData data) {
  final taskIds = <String>{};
  final captureItemIds = <String>{};
  for (final item in data.parsed) {
    if (item.kind == ParsedItemKind.matched ||
        item.kind == ParsedItemKind.update) {
      final taskId = item.matchedTaskId;
      if (taskId != null) {
        taskIds.add(taskId);
      } else {
        captureItemIds.add(item.id);
      }
    } else {
      captureItemIds.add(item.id);
    }
  }
  for (final entry in data.triageDecisions.entries) {
    final action = entry.value.action;
    if (action == TriageAction.today || action == TriageAction.doNow) {
      taskIds.add(entry.key);
    }
  }
  return (taskIds: taskIds.toList(), captureItemIds: captureItemIds.toList());
}

/// Scaffold-free reconcile content (the Heard / Decide columns) for hosting
/// inside the day-planning modal. Unlike [_ReconcileBody] it carries no
/// footer — the modal's sticky glass action bar supplies the Re-record /
/// Build day actions — and it does not scroll itself (the modal page's
/// sliver scroll viewport owns scrolling).
class ReconcileModalContent extends StatelessWidget {
  const ReconcileModalContent({
    required this.params,
    required this.data,
    super.key,
  });

  final ReconcileParams params;
  final ReconcileData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final heardColumn = _HeardColumn(params: params, items: data.parsed);
    final decideColumn = _DecideColumn(params: params, items: data.pending);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step5,
      ),
      // Decide two-column vs stacked from the actual available width (the
      // modal/dialog box), not the screen size — the dialog can be far
      // narrower than the screen.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= _reconcileTwoColumnBreakpoint;
          // Same headline system as the Capture step, so the ritual keeps
          // one header spine across pages.
          final header = Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step6),
            child: Text(
              context.messages.dailyOsNextReconcileHeadline,
              textAlign: TextAlign.center,
              style: calmDisplayStyle(tokens),
            ),
          );
          if (!isWide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                heardColumn,
                SizedBox(height: tokens.spacing.step6),
                decideColumn,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: _heardColumnFlex, child: heardColumn),
                  SizedBox(width: tokens.spacing.step6),
                  Expanded(flex: _decideColumnFlex, child: decideColumn),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReconcileFooter extends StatelessWidget {
  const _ReconcileFooter({required this.params, required this.data});

  final ReconcileParams params;
  final ReconcileData data;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isWide =
        MediaQuery.sizeOf(context).width >= _reconcileTwoColumnBreakpoint;
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
    );
    final buttonPadding = EdgeInsets.symmetric(
      horizontal: tokens.spacing.step5,
      vertical: tokens.spacing.step3,
    );
    final retryButton = FilledButton.icon(
      icon: Icon(Icons.mic_rounded, size: tokens.spacing.step4),
      label: Text(
        messages.dailyOsNextReconcileReRecord,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: tokens.colors.surface.focusPressed,
        foregroundColor: tokens.colors.text.highEmphasis,
        minimumSize: Size(0, tokens.spacing.step9),
        padding: buttonPadding,
        shape: buttonShape,
      ),
      onPressed: () => Navigator.of(context).maybePop(),
    );
    final hint = Text(
      messages.dailyOsNextReconcileVoiceHint,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.lowEmphasis,
      ),
      textAlign: TextAlign.center,
    );
    final draftButton = FilledButton.icon(
      onPressed: () {
        final selections = reconcileDraftingSelections(data);
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => DraftingPage(
              captureId: params.captureId,
              decidedTaskIds: selections.taskIds,
              decidedCaptureItemIds: selections.captureItemIds,
              dayDate: params.dayDate,
              returnToRootOnReady: true,
            ),
          ),
        );
      },
      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
      label: Text(
        messages.dailyOsNextReconcileBuildDayCta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: FilledButton.styleFrom(
        backgroundColor: tokens.colors.interactive.enabled,
        foregroundColor: tokens.colors.text.onInteractiveAlert,
        minimumSize: Size(0, tokens.spacing.step9),
        padding: buttonPadding,
        shape: buttonShape,
      ),
    );
    return DesignSystemGlassStrip(
      child: isWide
          ? Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step6,
                vertical: tokens.spacing.step4,
              ),
              child: Row(
                children: [
                  retryButton,
                  Expanded(child: hint),
                  draftButton,
                ],
              ),
            )
          : Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  hint,
                  SizedBox(height: tokens.spacing.step3),
                  Row(
                    children: [
                      Expanded(child: retryButton),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(child: draftButton),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
