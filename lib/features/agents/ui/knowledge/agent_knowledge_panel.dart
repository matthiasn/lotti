import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge.dart';
import 'package:lotti/features/agents/knowledge/agent_knowledge_providers.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The "What I've learned" panel (ADR 0022 Decisions 9–10): the durable things
/// an agent remembers — the day planner about how the user wants to be
/// planned, a goal's agent about the goal — surfaced for the user to confirm,
/// edit, or forget. Proposals await the user's confirmation; confirmed entries
/// are the active Head set.
///
/// The two read differently on purpose: a proposal is a question the agent is
/// asking, so it stands in a toned callout with its decision under it; a
/// confirmed fact is something already settled, so it reads as plain text
/// with its rarer actions behind a menu.
class AgentKnowledgePanel extends ConsumerWidget {
  const AgentKnowledgePanel({required this.agentId, super.key});

  /// Whose knowledge this is.
  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
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
                  messages.agentKnowledgeLoadError,
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
          // The header row is as tall as the goal page's "About this goal"
          // header with its icon actions, so the two siblings' titles sit
          // at the same height in their cards.
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: TapTargets.minimum),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                messages.agentKnowledgeTitle,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          if (view.isEmpty)
            Text(
              messages.agentKnowledgeEmpty,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          if (view.proposed.isNotEmpty) ...[
            _GroupLabel(messages.agentKnowledgeProposedHeader),
            for (final (index, entry) in view.proposed.indexed) ...[
              if (index > 0) SizedBox(height: tokens.spacing.step3),
              _Proposal(agentId: agentId, entry: entry),
            ],
          ],
          if (view.confirmed.isNotEmpty) ...[
            // No label of their own — plain text is what is settled — but a
            // rule closes the agent's question above, so it does not seem
            // to ask about these too.
            if (view.proposed.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
                child: const DesignSystemDivider(),
              ),
            for (final (index, entry) in view.confirmed.indexed) ...[
              // A rule between facts, padded as between the charter's
              // entries.
              // Each row is already a full tap target high, so the rule
              // between facts needs little air of its own.
              if (index > 0)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                  child: const DesignSystemDivider(),
                ),
              _ConfirmedFact(agentId: agentId, entry: entry),
            ],
          ],
        ],
      ),
    );
  }
}

/// A group's key — the label for the facts under it, not metadata to fade.
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Semantics(
        header: true,
        child: Text(label, style: captionLabelStyle(tokens)),
      ),
    );
  }
}

/// A fact the agent proposes: the agent's question, in the agent's own
/// colour so it is never mistaken for what the user said, with the user's
/// answer under it — Confirm the positive way forward, Forget the quiet way
/// out.
class _Proposal extends ConsumerWidget {
  const _Proposal({required this.agentId, required this.entry});

  final String agentId;
  final PlannerKnowledgeEntity entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemInlineCallout(
      key: ValueKey('agent-knowledge-proposal-${entry.id}'),
      icon: LottiIcons.aiSpark,
      tone: tokens.colors.aiCard.accent,
      text: entry.statementText,
      actions: [
        DesignSystemButton(
          label: messages.agentKnowledgeRetract,
          variant: DesignSystemButtonVariant.quiet,
          tapTargetSize: MaterialTapTargetSize.padded,
          semanticsLabel:
              '${messages.agentKnowledgeRetract}: ${entry.statementText}',
          onPressed: () => _retract(ref, agentId, entry),
        ),
        DesignSystemButton(
          label: messages.agentKnowledgeConfirm,
          leadingIcon: LottiIcons.confirm,
          variant: DesignSystemButtonVariant.constructiveOutlined,
          tapTargetSize: MaterialTapTargetSize.padded,
          semanticsLabel:
              '${messages.agentKnowledgeConfirm}: ${entry.statementText}',
          onPressed: () => _confirm(ref, agentId, entry),
        ),
      ],
    );
  }
}

/// A settled fact: its words, a re-confirmation nudge once it is due for
/// review, its tags — and Edit and Forget behind one menu, so a long list
/// reads as facts rather than as rows of buttons.
class _ConfirmedFact extends ConsumerWidget {
  const _ConfirmedFact({required this.agentId, required this.entry});

  final String agentId;
  final PlannerKnowledgeEntity entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isStale =
        entry.reviewAfter != null && !entry.reviewAfter!.isAfter(clock.now());
    // The same size as a proposal's words in its callout: a fact does not
    // change size when it is confirmed.
    final style = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    // The menu keeps its full target inside the row, never overhanging it
    // (hit testing stops at a box's own size): the words drop by half the
    // difference, so their first line — at any text scale — centres on the
    // glyph.
    final line =
        MediaQuery.textScalerOf(context).scale(style.fontSize!) *
        (style.height ?? 1);
    final firstLineInset = math.max(0, (TapTargets.minimum - line) / 2);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: firstLineInset.toDouble()),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.statementText, style: style),
                if (isStale) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Row(
                    children: [
                      Icon(
                        LottiIcons.warning,
                        size: IconSizes.s,
                        color: tokens.colors.alert.warning.defaultColor,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      Flexible(
                        child: Text(
                          messages.agentKnowledgeStale,
                          style: tokens.typography.styles.others.caption
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                      ),
                      SizedBox(width: tokens.spacing.step2),
                      // Answering the question in place: re-confirming renews
                      // the fact and clears its review.
                      DesignSystemButton(
                        key: ValueKey('agent-knowledge-reconfirm-${entry.id}'),
                        label: messages.agentKnowledgeStillTrueYes,
                        leadingIcon: LottiIcons.confirm,
                        size: DesignSystemButtonSize.dense,
                        variant: DesignSystemButtonVariant.tertiary,
                        tapTargetSize: MaterialTapTargetSize.padded,
                        semanticsLabel:
                            '${messages.agentKnowledgeConfirm}: '
                            '${entry.statementText}',
                        onPressed: () => _confirm(ref, agentId, entry),
                      ),
                    ],
                  ),
                ],
                if (entry.tags.isNotEmpty) ...[
                  SizedBox(height: tokens.spacing.step2),
                  Wrap(
                    spacing: tokens.spacing.step2,
                    runSpacing: tokens.spacing.step2,
                    children: [
                      for (final tag in entry.tags)
                        DsPill(
                          variant: DsPillVariant.filled,
                          shape: DsPillShape.tag,
                          label: tag,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        _menu(context, ref),
      ],
    );
  }

  Widget _menu(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemContextMenuButton(
      key: ValueKey('agent-knowledge-menu-${entry.id}'),
      iconColor: tokens.colors.text.mediumEmphasis,
      tooltip: messages.agentKnowledgeFactOptions,
      semanticsLabel:
          '${messages.agentKnowledgeFactOptions}: ${entry.statementText}',
      items: [
        DesignSystemContextMenuItem(
          label: messages.agentKnowledgeEdit,
          icon: LottiIcons.edit,
          onTap: () => _edit(context, ref),
        ),
        DesignSystemContextMenuItem(
          label: messages.agentKnowledgeRetract,
          icon: LottiIcons.delete,
          isDestructive: true,
          onTap: () => _retract(ref, agentId, entry),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final result = await DsActionModal.show<({String hook, String statement})>(
      context: context,
      title: context.messages.agentKnowledgeEditTitle,
      builder: (_) => _KnowledgeEditForm(entry: entry),
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

Future<void> _confirm(
  WidgetRef ref,
  String agentId,
  PlannerKnowledgeEntity entry,
) async {
  await ref.read(agentKnowledgeServiceProvider).confirm(entry.id);
  ref.invalidate(agentKnowledgeProvider(agentId));
}

Future<void> _retract(
  WidgetRef ref,
  String agentId,
  PlannerKnowledgeEntity entry,
) async {
  await ref.read(agentKnowledgeServiceProvider).retract(entry.id);
  ref.invalidate(agentKnowledgeProvider(agentId));
}

/// The edit sheet's body: the one-line hook and the fact in full, saved only
/// when both say something. It pops its own result; the caller writes it.
class _KnowledgeEditForm extends StatefulWidget {
  const _KnowledgeEditForm({required this.entry});

  final PlannerKnowledgeEntity entry;

  @override
  State<_KnowledgeEditForm> createState() => _KnowledgeEditFormState();
}

class _KnowledgeEditFormState extends State<_KnowledgeEditForm> {
  late final TextEditingController _hook = TextEditingController(
    text: widget.entry.hook,
  );
  late final TextEditingController _statement = TextEditingController(
    text: widget.entry.statementText,
  );

  @override
  void initState() {
    super.initState();
    _hook.addListener(_changed);
    _statement.addListener(_changed);
  }

  void _changed() => setState(() {});

  bool get _canSave =>
      _hook.text.trim().isNotEmpty && _statement.text.trim().isNotEmpty;

  @override
  void dispose() {
    _hook.dispose();
    _statement.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemTextarea(
          key: const ValueKey('agent-knowledge-edit-hook'),
          controller: _hook,
          label: messages.agentKnowledgeEditHookHint,
          // The hook is the always-on index line (ADR 0022 Decision 10);
          // cap it here so the service-level guard is never hit and the
          // user sees how much room is left.
          maxLength: knowledgeHookMaxLength,
          showCounter: true,
          minLines: 1,
          maxLines: 2,
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemTextarea(
          key: const ValueKey('agent-knowledge-edit-statement'),
          controller: _statement,
          label: messages.agentKnowledgeEditStatementHint,
          growWithContent: true,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemModalActionBar(
          primary: DesignSystemButton(
            key: const ValueKey('agent-knowledge-edit-save'),
            label: messages.agentKnowledgeEditSave,
            size: DesignSystemButtonSize.large,
            fullWidth: true,
            onPressed: _canSave
                ? () => Navigator.of(context).pop((
                    hook: _hook.text.trim(),
                    statement: _statement.text.trim(),
                  ))
                : null,
          ),
          secondary: [
            DesignSystemButton(
              key: const ValueKey('agent-knowledge-edit-cancel'),
              label: messages.agentKnowledgeEditCancel,
              variant: DesignSystemButtonVariant.quiet,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ],
    );
  }
}
