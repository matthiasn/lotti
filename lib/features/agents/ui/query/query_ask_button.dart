import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_chat_providers.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
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
    super.key,
  });
  final QueryScope scope;
  final bool fullLabel;

  /// The glyph-only disc for an agent card's header rail, matching the
  /// read-aloud control beside it; the scoped label is its tooltip and what
  /// a screen reader hears.
  final bool disc;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(queryChatEnabledProvider)) return const SizedBox.shrink();
    final messages = context.messages;
    final label = switch (scope.kind) {
      QueryScopeKind.task => messages.queryAskTask,
      QueryScopeKind.project => messages.queryAskProject,
      QueryScopeKind.category => messages.queryAskCategory,
    };
    void open() => ref.read(queryPaneOpenProvider(scope).notifier).open = true;
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
