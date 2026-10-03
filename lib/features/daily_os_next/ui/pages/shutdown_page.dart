import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/shutdown_controller.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/daily_os_next/ui/pages/shutdown_cards.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/knowledge_panel.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

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
          icon: const Icon(LottiIcons.back),
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
        MetricsCard(metrics: data.metrics),
        SizedBox(height: tokens.spacing.step5),
        ReflectionCard(forDate: forDate),
        SizedBox(height: tokens.spacing.step5),
        // Durable "what I've learned" knowledge (ADR 0022) — confirm/edit/forget
        // the things the planner remembers about how you want to be planned.
        const KnowledgePanel(),
        SizedBox(height: tokens.spacing.step5),
        TomorrowNoteCard(forDate: forDate),
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
        ShutdownFooter(forDate: forDate),
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

/// Evening-review section listing what got done today — each [CompletedItem]
/// as a [_CompletedRow] with its tracked duration.
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
          icon: LottiIcons.confirmCircled,
          label: context.messages.dailyOsNextShutdownCompletedOverline,
          count: items.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        if (items.isEmpty)
          _EmptyLine(context.messages.dailyOsNextShutdownCompletedEmpty),
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
    final messages = context.messages;
    final details = [
      if (item.sessionCount > 0)
        messages.dailyOsNextShutdownCompletedSessions(item.sessionCount),
      if (item.doneToday) messages.dailyOsNextShutdownCompletedDoneToday,
    ].join(' · ');
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
          Icon(
            item.doneToday ? LottiIcons.confirm : LottiIcons.forward,
            size: 16,
            color: item.doneToday
                ? tokens.colors.alert.success.defaultColor
                : tokens.colors.text.lowEmphasis,
          ),
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
                if (details.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    details,
                    style: tokens.typography.styles.body.bodySmall.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (item.durationMinutes > 0) ...[
            SizedBox(width: tokens.spacing.step3),
            Text(
              '${item.durationMinutes}m',
              style: monoMetaStyle(tokens, tokens.colors),
            ),
          ],
        ],
      ),
    );
  }
}

/// Evening-review section listing unfinished work — each [CarryoverItem] as a
/// [_CarryoverRow] whose action applies a [CarryoverAction] (move to tomorrow,
/// drop, etc.) through the shutdown controller.
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
          icon: LottiIcons.forwardCircled,
          label: context.messages.dailyOsNextShutdownCarryoverOverline,
          count: data.carryover.length,
        ),
        SizedBox(height: tokens.spacing.step4),
        if (data.carryover.isEmpty)
          _EmptyLine(context.messages.dailyOsNextShutdownCarryoverEmpty),
        for (final item in data.carryover) ...[
          _CarryoverRow(
            item: item,
            decision: data.decisions[item.taskId],
            onAction: (action) => _decide(context, ref, forDate, item, action),
          ),
          SizedBox(height: tokens.spacing.step3),
        ],
      ],
    );
  }
}

/// Applies [action] to [item]; a picked date comes from the date picker,
/// starting on the suggested day. A failed write leaves the row undecided and
/// says so.
Future<void> _decide(
  BuildContext context,
  WidgetRef ref,
  DateTime forDate,
  CarryoverItem item,
  CarryoverAction action,
) async {
  DateTime? when;
  if (action == CarryoverAction.pickDate) {
    final suggested = item.suggestedDate;
    final picked = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.dailyOsNextShutdownCarryoverPickDate,
      initialDate: suggested,
      firstDate: suggested,
      lastDate: DateTime(suggested.year + 1, suggested.month, suggested.day),
    );
    when = picked?.date;
    if (when == null) return;
  }
  try {
    await ref
        .read(shutdownControllerProvider(forDate).notifier)
        .applyCarryover(taskId: item.taskId, action: action, when: when);
  } on Object {
    if (context.mounted) showShutdownActionFailed(context);
  }
}

/// "Tomorrow" when [date] is the day after today, otherwise the date itself.
String _dayLabel(BuildContext context, DateTime date) {
  final now = clock.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  if (DateUtils.isSameDay(date, tomorrow)) {
    return context.messages.dailyOsNextShutdownCarryoverTomorrow;
  }
  return DateFormat.MMMEd(
    Localizations.localeOf(context).toString(),
  ).format(date);
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Text(
      text,
      style: tokens.typography.styles.body.bodySmall.copyWith(
        color: tokens.colors.text.mediumEmphasis,
      ),
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
  final CarryoverDecision? decision;
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
                Flexible(child: CategoryChip(category: item.category)),
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              item.loggedMinutes > 0
                  ? context.messages.dailyOsNextShutdownCarryoverStarted(
                      item.loggedMinutes,
                    )
                  : context.messages.dailyOsNextShutdownCarryoverNotStarted,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step3),
            if (decided)
              _DecisionPill(decision: decision!)
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
          icon: const Icon(LottiIcons.forward, size: 14),
          label: Text(_dayLabel(context, item.suggestedDate)),
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
  const _DecisionPill({required this.decision});

  final CarryoverDecision decision;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final movedTo = decision.movedTo;
    final label = movedTo == null
        ? context.messages.dailyOsNextShutdownCarryoverDropped
        : _dayLabel(context, movedTo);
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
          Icon(LottiIcons.confirm, size: 14, color: teal),
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
