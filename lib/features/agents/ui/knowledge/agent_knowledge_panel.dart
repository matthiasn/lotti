import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The "What I've learned" panel (ADR 0022 Decisions 9–10): the durable things
/// an agent remembers — the day planner about how the user wants to be
/// planned, a goal's agent about the goal — surfaced for the user to confirm,
/// edit, or forget. Proposals await the user's confirmation; confirmed entries
/// are the active Head set.
class AgentKnowledgePanel extends ConsumerWidget {
  const AgentKnowledgePanel({required this.agentId, super.key});

  /// Whose knowledge this is.
  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    // Use the last resolved value (not maybeWhen) so a confirm/retract/edit
    // invalidation keeps the panel rendered during the background refresh
    // instead of flashing to empty (repo no-flash rule).
    final async = ref.watch(agentKnowledgeProvider(agentId));
    final view = async.value;
    if (view == null) {
      // First load / error with no prior value: the panel is sometimes the
      // SOLE content of a modal, so a silent shrink would read as a broken
      // blank sheet.
      return Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Center(
          child: async.hasError
              ? Text(
                  context.messages.dailyOsNextGenericError,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                )
              : const DesignSystemSpinner(size: IconSizes.l),
        ),
      );
    }

    return DesignSystemSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The same header tier as the goal page's "About this goal" card
          // beside it, so the two read as siblings.
          Text(
            context.messages.agentKnowledgeTitle,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          if (view.isEmpty)
            Text(
              context.messages.agentKnowledgeEmpty,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          if (view.proposed.isNotEmpty)
            _KnowledgeGroup(
              agentId: agentId,
              label: context.messages.agentKnowledgeProposedHeader,
              entries: view.proposed,
              proposed: true,
            ),
          if (view.confirmed.isNotEmpty) ...[
            if (view.proposed.isNotEmpty)
              SizedBox(height: tokens.spacing.step5),
            _KnowledgeGroup(
              agentId: agentId,
              label: context.messages.agentKnowledgeConfirmedHeader,
              entries: view.confirmed,
              proposed: false,
            ),
          ],
        ],
      ),
    );
  }
}

/// One status group: a caption-tier label over its facts, a rule between
/// facts as between the charter's entries.
class _KnowledgeGroup extends StatelessWidget {
  const _KnowledgeGroup({
    required this.agentId,
    required this.label,
    required this.entries,
    required this.proposed,
  });

  final String agentId;
  final String label;
  final List<PlannerKnowledgeEntity> entries;
  final bool proposed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        for (final (index, entry) in entries.indexed) ...[
          if (index > 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
              child: const DesignSystemDivider(),
            ),
          _KnowledgeRow(agentId: agentId, entry: entry, proposed: proposed),
        ],
      ],
    );
  }
}

class _KnowledgeRow extends ConsumerWidget {
  const _KnowledgeRow({
    required this.agentId,
    required this.entry,
    required this.proposed,
  });

  final String agentId;
  final PlannerKnowledgeEntity entry;
  final bool proposed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final isStale =
        entry.reviewAfter != null && !entry.reviewAfter!.isAfter(clock.now());

    return Column(
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
            context.messages.agentKnowledgeStale,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.alert.warning.ink,
            ),
          ),
        ],
        if (entry.tags.isNotEmpty) ...[
          SizedBox(height: tokens.spacing.step2),
          Wrap(
            spacing: tokens.spacing.step2,
            runSpacing: tokens.spacing.step2,
            children: [
              for (final tag in entry.tags)
                DsPill(variant: DsPillVariant.filled, label: tag),
            ],
          ),
        ],
        SizedBox(height: tokens.spacing.step1),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (proposed)
              DesignSystemButton(
                label: context.messages.agentKnowledgeConfirm,
                size: DesignSystemButtonSize.dense,
                variant: DesignSystemButtonVariant.tertiary,
                onPressed: () => _confirm(ref),
              )
            else
              DesignSystemButton(
                label: context.messages.agentKnowledgeEdit,
                size: DesignSystemButtonSize.dense,
                variant: DesignSystemButtonVariant.quiet,
                onPressed: () => _edit(context, ref),
              ),
            SizedBox(width: tokens.spacing.step2),
            DesignSystemButton(
              label: context.messages.agentKnowledgeRetract,
              size: DesignSystemButtonSize.dense,
              variant: DesignSystemButtonVariant.quiet,
              onPressed: () => _retract(ref),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _confirm(WidgetRef ref) async {
    await ref.read(agentKnowledgeServiceProvider).confirm(entry.id);
    ref.invalidate(agentKnowledgeProvider(agentId));
  }

  Future<void> _retract(WidgetRef ref) async {
    await ref.read(agentKnowledgeServiceProvider).retract(entry.id);
    ref.invalidate(agentKnowledgeProvider(agentId));
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<({String hook, String statement})>(
      context: context,
      builder: (_) => _EditDialog(entry: entry),
    );
    if (result == null) return;
    await ref
        .read(agentKnowledgeServiceProvider)
        .editStatement(
          entry.id,
          hook: result.hook,
          statement: result.statement,
        );
    ref.invalidate(agentKnowledgeProvider(agentId));
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
      title: Text(context.messages.agentKnowledgeEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _hook,
            // The hook is the always-on index line (ADR 0022 Decision 10);
            // cap it in the UI so the service-level guard is never hit and the
            // user gets a live character counter.
            maxLength: knowledgeHookMaxLength,
            decoration: InputDecoration(
              hintText: context.messages.agentKnowledgeEditHookHint,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          TextField(
            controller: _statement,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.messages.agentKnowledgeEditStatementHint,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.messages.agentKnowledgeEditCancel),
        ),
        FilledButton(
          onPressed: () {
            final hook = _hook.text.trim();
            final statement = _statement.text.trim();
            if (hook.isEmpty || statement.isEmpty) return;
            Navigator.of(context).pop((hook: hook, statement: statement));
          },
          child: Text(context.messages.agentKnowledgeEditSave),
        ),
      ],
    );
  }
}
