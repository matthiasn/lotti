import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

part 'shutdown_cards.dart';

/// End-of-day surface. Mirrors `prototype/screens/closing.jsx →
/// ShutdownDesktop`. Two columns, scrollable.
class ShutdownPage extends ConsumerWidget {
  const ShutdownPage({required this.forDate, super.key});

  final DateTime forDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final asyncState = ref.watch(shutdownControllerProvider(forDate));
    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        title: Text(
          context.messages.dailyOsNextShutdownTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: switch (asyncState) {
          _ when asyncState.hasValue => _ShutdownBody(
            forDate: forDate,
            data: asyncState.requireValue,
          ),
          _ when asyncState.hasError => Center(
            child: Text(
              context.messages.dailyOsNextGenericError,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

class _ShutdownBody extends ConsumerWidget {
  const _ShutdownBody({required this.forDate, required this.data});

  final DateTime forDate;
  final ShutdownData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CompletedSection(items: data.completed),
        SizedBox(height: tokens.spacing.step6),
        _CarryoverSection(forDate: forDate, data: data),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricsCard(metrics: data.metrics),
        SizedBox(height: tokens.spacing.step5),
        _ReflectionCard(forDate: forDate),
        SizedBox(height: tokens.spacing.step5),
        _TomorrowNoteCard(note: data.tomorrowNote),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(tokens.spacing.step6),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: left),
                      SizedBox(width: tokens.spacing.step6),
                      Expanded(flex: 5, child: right),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      SizedBox(height: tokens.spacing.step6),
                      right,
                    ],
                  ),
          ),
        ),
        const _ShutdownFooter(),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Row(
      children: [
        Icon(icon, size: 14, color: tokens.colors.text.mediumEmphasis),
        SizedBox(width: tokens.spacing.step2),
        Text(
          label,
          style: calmEyebrowStyle(tokens),
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

class _CompletedSection extends StatelessWidget {
  const _CompletedSection({required this.items});

  final List<CompletedItem> items;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.check_circle_outline_rounded,
          label: context.messages.dailyOsNextShutdownCompletedOverline,
          count: items.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        for (final item in items) ...[
          _CompletedRow(item: item),
          SizedBox(height: tokens.spacing.step3),
        ],
      ],
    );
  }
}

class _CompletedRow extends StatelessWidget {
  const _CompletedRow({required this.item});

  final CompletedItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = categoryColorFromHex(item.category.colorHex);
    final success = tokens.colors.alert.success.defaultColor;
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_rounded, size: 16, color: success),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.highEmphasis,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.note != null) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    item.note!,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Text(
            '${item.durationMinutes}m',
            style: monoMetaStyle(tokens, tokens.colors),
          ),
        ],
      ),
    );
  }
}

class _CarryoverSection extends ConsumerWidget {
  const _CarryoverSection({required this.forDate, required this.data});

  final DateTime forDate;
  final ShutdownData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(
          icon: Icons.arrow_circle_right_outlined,
          label: context.messages.dailyOsNextShutdownCarryoverOverline,
          count: data.carryover.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        for (final item in data.carryover) ...[
          _CarryoverRow(
            item: item,
            decision: data.decisions[item.taskId],
            onAction: (action) async {
              await ref
                  .read(shutdownControllerProvider(forDate).notifier)
                  .applyCarryover(taskId: item.taskId, action: action);
            },
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
      ],
    );
  }
}

class _CarryoverRow extends StatelessWidget {
  const _CarryoverRow({
    required this.item,
    required this.decision,
    required this.onAction,
  });

  final CarryoverItem item;
  final CarryoverAction? decision;
  final ValueChanged<CarryoverAction> onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = categoryColorFromHex(item.category.colorHex);
    final decided = decision != null;
    return Opacity(
      opacity: decided ? 0.55 : 1.0,
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: tokens.colors.background.level02,
          borderRadius: BorderRadius.circular(tokens.radii.m),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.highEmphasis,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: tokens.spacing.step3),
                CategoryChip(category: item.category),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              item.reason,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            if (decided)
              _DecisionPill(action: decision!, target: item.suggestedTarget)
            else
              _CarryoverActions(item: item, onAction: onAction),
          ],
        ),
      ),
    );
  }
}

class _CarryoverActions extends StatelessWidget {
  const _CarryoverActions({required this.item, required this.onAction});

  final CarryoverItem item;
  final ValueChanged<CarryoverAction> onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;
    return Wrap(
      spacing: tokens.spacing.step2,
      runSpacing: tokens.spacing.step2,
      children: [
        FilledButton.icon(
          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
          label: Text(item.suggestedTarget),
          style: FilledButton.styleFrom(
            backgroundColor: teal,
            foregroundColor: tokens.colors.text.onInteractiveAlert,
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step2,
            ),
            textStyle: tokens.typography.styles.body.bodySmall,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
          onPressed: () => onAction(CarryoverAction.tomorrow),
        ),
        OutlinedButton(
          onPressed: () => onAction(CarryoverAction.pickDate),
          style: OutlinedButton.styleFrom(
            foregroundColor: tokens.colors.text.mediumEmphasis,
            side: BorderSide(color: tokens.colors.decorative.level01),
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step3,
              vertical: tokens.spacing.step2,
            ),
            textStyle: tokens.typography.styles.body.bodySmall,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
          ),
          child: Text(messages.dailyOsNextShutdownCarryoverPickDate),
        ),
        TextButton(
          onPressed: () => onAction(CarryoverAction.drop),
          style: TextButton.styleFrom(
            foregroundColor: tokens.colors.text.lowEmphasis,
          ),
          child: Text(messages.dailyOsNextShutdownCarryoverDrop),
        ),
      ],
    );
  }
}

class _DecisionPill extends StatelessWidget {
  const _DecisionPill({required this.action, required this.target});

  final CarryoverAction action;
  final String target;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final label = switch (action) {
      CarryoverAction.tomorrow => target,
      CarryoverAction.pickDate =>
        context.messages.dailyOsNextShutdownCarryoverScheduled,
      CarryoverAction.drop =>
        context.messages.dailyOsNextShutdownCarryoverDropped,
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      decoration: BoxDecoration(
        color: teal.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        border: Border.all(color: teal.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: teal),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: teal,
            ),
          ),
        ],
      ),
    );
  }
}
