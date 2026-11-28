import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Opens discussion on the existing scope. Opening has no model request or
/// effect on the agent's automatic-update preference.
class QueryAskButton extends ConsumerWidget {
  const QueryAskButton({
    required this.scope,
    this.fullLabel = false,
    this.disc = false,
    this.inline = false,
    super.key,
  });
  final QueryScope scope;
  final bool fullLabel;

  /// The glyph-only disc for an agent card's header rail, matching the
  /// read-aloud control beside it; the scoped label is its tooltip and what
  /// a screen reader hears.
  final bool disc;

  /// A labelled caption-tier action in the agent's violet, for a surface
  /// that is not the agent's own card: it still reads as the agent, and
  /// says what it does without a tooltip. Carries the scoped label.
  final bool inline;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(queryChatEnabledProvider)) return const SizedBox.shrink();
    final messages = context.messages;
    final label = switch (scope.kind) {
      QueryScopeKind.task => messages.queryAskTask,
      QueryScopeKind.project => messages.queryAskProject,
      QueryScopeKind.category => messages.queryAskCategory,
      // No pane hosts a journal or unknown scope (it refuses a scope with no
      // visible home or category); the arm keeps the switch total.
      QueryScopeKind.journal || QueryScopeKind.unknown => messages.queryAsk,
    };
    void open() => ref.read(queryPaneOpenProvider(scope).notifier).open = true;
    if (inline) {
      final accent = context.designTokens.colors.aiCard.accent;
      // Hugs its label: in a Wrap of buttons the action's own Align would
      // otherwise claim a whole line.
      return IntrinsicWidth(
        child: DesignSystemInlineAction(
          // Semibold at body size: the agent's way in reads as an action,
          // not as the faintest metadata on the page.
          labelWidget: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.designTokens.typography.styles.body.bodySmall
                .copyWith(
                  color: accent,
                  fontWeight: context.designTokens.typography.weight.semiBold,
                ),
          ),
          semanticsLabel: label,
          leadingIcon: LottiIcons.chat,
          ink: accent,
          onTap: open,
        ),
      );
    }
    return disc
        ? DsAiDiscButton(icon: LottiIcons.chat, label: label, onPressed: open)
        : DesignSystemButton(
            label: fullLabel ? label : messages.queryAsk,
            semanticsLabel: label,
            leadingIcon: LottiIcons.chat,
            onPressed: open,
            variant: DesignSystemButtonVariant.outlined,
            size: fullLabel
                ? DesignSystemButtonSize.small
                : DesignSystemButtonSize.large,
          );
  }
}
