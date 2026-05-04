import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_badge_widgets.dart';
import 'package:lotti/features/agents/ui/agent_internals_body.dart';
import 'package:lotti/features/agents/ui/agent_nav_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Detail page for a single agent.
///
/// Watches the agent's identity, state, and latest report, and renders them
/// in a scrollable layout with controls for lifecycle management.
class AgentDetailPage extends ConsumerWidget {
  const AgentDetailPage({
    required this.agentId,
    super.key,
  });

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identityAsync = ref.watch(agentIdentityProvider(agentId));
    final stateAsync = ref.watch(agentStateProvider(agentId));

    // Use .value to preserve previous data during stream-triggered reloads,
    // preventing a flash-to-empty while the provider re-fetches.
    final identityEntity = identityAsync.value;

    // Still show initial loading spinner on first load.
    if (identityAsync.isLoading && identityEntity == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (identityAsync.hasError && identityEntity == null) {
      return Scaffold(
        appBar: AppBar(
          leading: agentBackButton(context),
        ),
        body: Center(
          child: Text(
            context.messages.agentDetailErrorLoading(
              identityAsync.error.toString(),
            ),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.error,
            ),
          ),
        ),
      );
    }

    if (identityEntity == null) {
      return Scaffold(
        appBar: AppBar(
          leading: agentBackButton(context),
        ),
        body: Center(
          child: Text(
            context.messages.agentDetailNotFound,
            style: context.textTheme.bodyLarge,
          ),
        ),
      );
    }

    final identity = identityEntity.mapOrNull(agent: (e) => e);
    if (identity == null) {
      return Scaffold(
        appBar: AppBar(
          leading: agentBackButton(context),
        ),
        body: Center(
          child: Text(
            context.messages.agentDetailUnexpectedType,
            style: context.textTheme.bodyLarge,
          ),
        ),
      );
    }

    final isRunning =
        ref.watch(agentIsRunningProvider(identity.agentId)).value ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: agentBackButton(context),
        title: Row(
          children: [
            Flexible(
              child: Text(
                identity.displayName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.spacingSmall),
            AgentLifecycleBadge(lifecycle: identity.lifecycle),
            if (isRunning) ...[
              const SizedBox(width: AppTheme.spacingMedium),
              Tooltip(
                message: context.messages.agentRunningIndicator,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: AppTheme.spacingLarge,
          ),
          child: AgentInternalsBody(
            agentId: agentId,
            lifecycle: identity.lifecycle,
            stateAsync: stateAsync,
          ),
        ),
      ),
    );
  }
}
