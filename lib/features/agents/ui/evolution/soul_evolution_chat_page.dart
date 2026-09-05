import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_composer_width.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_list.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_opening.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Chat-based evolution page for standalone soul evolution sessions.
///
/// Provides a multi-turn conversation with the personality evolution agent,
/// inline soul proposal review, and message input.
class SoulEvolutionChatPage extends ConsumerStatefulWidget {
  const SoulEvolutionChatPage({
    required this.soulId,
    super.key,
  });

  final String soulId;

  @override
  ConsumerState<SoulEvolutionChatPage> createState() =>
      _SoulEvolutionChatPageState();
}

class _SoulEvolutionChatPageState extends ConsumerState<SoulEvolutionChatPage> {
  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(
      soulEvolutionChatStateProvider(widget.soulId),
    );
    final soulAsync = ref.watch(soulDocumentProvider(widget.soulId));
    final soulName = soulAsync.value is SoulDocumentEntity
        ? (soulAsync.value! as SoulDocumentEntity).displayName
        : '';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Session cleanup happens via ref.onDispose in the notifier.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(soulName),
        ),
        body: chatAsync.when(
          data: (data) => _buildChat(context, data, soulName),
          loading: () => const EvolutionSessionOpening(),
          error: (error, _) => const _SoulChatError(),
        ),
        bottomNavigationBar: chatAsync.whenOrNull(
          data: (data) => EvolutionComposerWidth(
            child: EvolutionMessageInput(
              onSend: _handleSend,
              isWaiting: data.isWaiting,
              enabled: data.sessionId != null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChat(
    BuildContext context,
    EvolutionChatData data,
    String soulName,
  ) {
    // Nothing to converse with until the session exists — see the template
    // chat for why this state gets a page of its own.
    if (shouldShowSessionOpening(data)) {
      return const EvolutionSessionOpening();
    }

    return DetailContentWidth(
      child: EvolutionMessageList(
        messages: data.messages,
        isWaiting: data.isWaiting,
        processor: data.processor,
        resolveSystemText: resolveSoulSystemText,
      ),
    );
  }

  void _handleSend(String text) {
    ref
        .read(soulEvolutionChatStateProvider(widget.soulId).notifier)
        .sendMessage(text);
  }
}

class _SoulChatError extends StatelessWidget {
  const _SoulChatError();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step7),
        child: Text(
          context.messages.agentEvolutionSessionError,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}
