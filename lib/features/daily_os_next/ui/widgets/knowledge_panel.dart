import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/daily_os_next/agents/state/day_agent_providers.dart';
import 'package:lotti/features/daily_os_next/state/planner_knowledge_provider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The "What I've learned" panel (ADR 0022 Decisions 9–10): the durable things
/// the planner remembers about how the user wants to be planned, surfaced for
/// the user to confirm, edit, or forget. Proposals (agent-inferred) await the
/// user's confirmation; confirmed entries are the active Head set.
class KnowledgePanel extends ConsumerWidget {
  const KnowledgePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final asyncView = ref.watch(plannerKnowledgeProvider);

    return asyncView.maybeWhen(
      data: (view) {
        return Container(
          decoration: BoxDecoration(
            color: tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          padding: EdgeInsets.all(tokens.spacing.step5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.messages.dailyOsNextKnowledgeTitle,
                style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              if (view.isEmpty)
                Text(
                  context.messages.dailyOsNextKnowledgeEmpty,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              if (view.proposed.isNotEmpty) ...[
                _SectionHeader(
                  label: context.messages.dailyOsNextKnowledgeProposedHeader,
                ),
                for (final entry in view.proposed)
                  _KnowledgeRow(entry: entry, proposed: true),
              ],
              if (view.confirmed.isNotEmpty) ...[
                if (view.proposed.isNotEmpty)
                  SizedBox(height: tokens.spacing.step4),
                _SectionHeader(
                  label: context.messages.dailyOsNextKnowledgeConfirmedHeader,
                ),
                for (final entry in view.confirmed)
                  _KnowledgeRow(entry: entry, proposed: false),
              ],
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step2),
      child: Text(
        label.toUpperCase(),
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.mediumEmphasis,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _KnowledgeRow extends ConsumerWidget {
  const _KnowledgeRow({required this.entry, required this.proposed});

  final PlannerKnowledgeEntity entry;
  final bool proposed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final isStale =
        entry.reviewAfter != null &&
        !entry.reviewAfter!.isAfter(DateTime.now());

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.statementText,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (isStale) ...[
            SizedBox(height: tokens.spacing.step1),
            Text(
              context.messages.dailyOsNextKnowledgeStale,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.alert.warning.defaultColor,
              ),
            ),
          ],
          SizedBox(height: tokens.spacing.step2),
          Row(
            children: [
              if (proposed)
                _Action(
                  label: context.messages.dailyOsNextKnowledgeConfirm,
                  emphasized: true,
                  onPressed: () => _confirm(ref),
                )
              else
                _Action(
                  label: context.messages.dailyOsNextKnowledgeEdit,
                  onPressed: () => _edit(context, ref),
                ),
              SizedBox(width: tokens.spacing.step3),
              _Action(
                label: context.messages.dailyOsNextKnowledgeRetract,
                onPressed: () => _retract(ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(WidgetRef ref) async {
    await ref.read(dayAgentKnowledgeServiceProvider).confirm(entry.id);
    ref.invalidate(plannerKnowledgeProvider);
  }

  Future<void> _retract(WidgetRef ref) async {
    await ref.read(dayAgentKnowledgeServiceProvider).retract(entry.id);
    ref.invalidate(plannerKnowledgeProvider);
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String hook, String statement})>(
      context: context,
      builder: (_) => _EditDialog(entry: entry),
    );
    if (result == null) return;
    await ref
        .read(dayAgentKnowledgeServiceProvider)
        .editStatement(
          entry.id,
          hook: result.hook,
          statement: result.statement,
        );
    ref.invalidate(plannerKnowledgeProvider);
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = emphasized
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.mediumEmphasis;
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step1,
        ),
        textStyle: tokens.typography.styles.body.bodySmall,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }
}

class _EditDialog extends StatefulWidget {
  const _EditDialog({required this.entry});

  final PlannerKnowledgeEntity entry;

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _hook = TextEditingController(
    text: widget.entry.hook,
  );
  late final TextEditingController _statement = TextEditingController(
    text: widget.entry.statementText,
  );

  @override
  void dispose() {
    _hook.dispose();
    _statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return AlertDialog(
      title: Text(context.messages.dailyOsNextKnowledgeEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hook,
            decoration: InputDecoration(
              hintText: context.messages.dailyOsNextKnowledgeEditHookHint,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          TextField(
            controller: _statement,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.messages.dailyOsNextKnowledgeEditStatementHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.messages.dailyOsNextKnowledgeEditCancel),
        ),
        FilledButton(
          onPressed: () {
            final hook = _hook.text.trim();
            final statement = _statement.text.trim();
            if (hook.isEmpty || statement.isEmpty) return;
            Navigator.of(context).pop((hook: hook, statement: statement));
          },
          child: Text(context.messages.dailyOsNextKnowledgeEditSave),
        ),
      ],
    );
  }
}
