import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/reconcile_controller.dart';
import 'package:lotti/features/daily_os_next/ui/pages/drafting_page.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/parsed_card.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/pending_card.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

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
    final isWide = MediaQuery.sizeOf(context).width >= 720;

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
                      Expanded(flex: 6, child: heardColumn),
                      SizedBox(width: tokens.spacing.step6),
                      Expanded(flex: 5, child: decideColumn),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnHeader(
          overline: context.messages.dailyOsNextReconcileHeardOverline,
          count: items.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        if (items.isEmpty)
          DottedBorder(
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
            style: tokens.typography.styles.others.overline.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
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
    return DottedBorder(
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

class _ReconcileFooter extends StatelessWidget {
  const _ReconcileFooter({required this.params, required this.data});

  final ReconcileParams params;
  final ReconcileData data;

  /// The work the user has effectively committed to taking on today.
  ///
  /// Matched/update parsed items and pending triage rows carry task IDs.
  /// NEW/unlinked parsed items carry parsed capture item IDs so drafting can
  /// still create tasks from the approved capture text before placing them.
  ({List<String> taskIds, List<String> captureItemIds}) _draftingSelections() {
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isWide = MediaQuery.sizeOf(context).width >= 720;
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
        final selections = _draftingSelections();
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

/// Simple dashed border decoration — used for secondary hint cards.
/// Inlined here rather than introducing a dependency on a 3rd-party
/// package. Strokes follow the design system decorative level.
class DottedBorder extends StatelessWidget {
  const DottedBorder({
    required this.child,
    required this.color,
    required this.radius,
    super.key,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: color, radius: radius),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1, size.height - 1),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0;
    const gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
