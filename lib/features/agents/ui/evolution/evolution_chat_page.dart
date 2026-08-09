import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_composer_width.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_list.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_opening.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Chat-based evolution page for template evolution sessions.
///
/// Provides a multi-turn conversation with the evolution agent, an inline
/// proposal review flow, and a one-line reminder of why the session exists.
class EvolutionChatPage extends ConsumerStatefulWidget {
  const EvolutionChatPage({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  ConsumerState<EvolutionChatPage> createState() => _EvolutionChatPageState();
}

class _EvolutionChatPageState extends ConsumerState<EvolutionChatPage> {
  @override
  Widget build(BuildContext context) {
    final chatAsync = ref.watch(evolutionChatStateProvider(widget.templateId));
    final templateAsync = ref.watch(agentTemplateProvider(widget.templateId));
    final templateEntity = templateAsync.value;
    final templateName = templateEntity is AgentTemplateEntity
        ? templateEntity.displayName
        : '';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Session cleanup happens via ref.onDispose in the notifier.
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: _ChatTitle(
            templateName: templateName,
            templateId: widget.templateId,
          ),
        ),
        body: chatAsync.when(
          data: (data) => _buildChat(context, data),
          loading: () => const EvolutionSessionOpening(),
          error: (error, _) => _ChatError(),
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

  Widget _buildChat(BuildContext context, EvolutionChatData data) {
    // Until the session exists there is nothing to converse with, and the
    // list would render a lone system line above an empty column. A failed
    // start is *not* that state — see `shouldShowSessionOpening`.
    if (shouldShowSessionOpening(data)) {
      return const EvolutionSessionOpening();
    }

    return DetailContentWidth(
      child: EvolutionMessageList(
        messages: data.messages,
        isWaiting: data.isWaiting,
        processor: data.processor,
        resolveSystemText: resolveTemplateSystemText,
      ),
    );
  }

  void _handleSend(String text) {
    ref
        .read(evolutionChatStateProvider(widget.templateId).notifier)
        .sendMessage(text);
  }
}

/// App-bar title: the agent's name over the one fact that explains why this
/// conversation is happening now. Replaces a collapsible Performance card
/// that repeated, in full, the card on the page you arrived from.
class _ChatTitle extends ConsumerWidget {
  const _ChatTitle({
    required this.templateName,
    required this.templateId,
  });

  final String templateName;
  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final metrics = ref.watch(ritualSummaryMetricsProvider(templateId)).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          templateName,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        if (metrics != null)
          Text(
            context.messages.agentRitualWakesSinceLastCount(
              metrics.wakesSinceLastSession,
            ),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

class _ChatError extends StatelessWidget {
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
