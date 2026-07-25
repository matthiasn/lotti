import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/ui/settings/util/profile_usage.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';

/// The inference profile ids some category default or agent setup routes
/// through — the source of the Profiles tab's "in use" badge.
///
/// Re-emits with the category stream, so binding or clearing a category's
/// profile updates the badge without a manual refresh. Agents are read once
/// per rebuild rather than watched: agent inference setups change from
/// settings surfaces the user has to navigate away to reach, and polling every
/// agent identity on each agent write would cost more than the badge is worth.
final FutureProvider<Set<String>> profileIdsInUseProvider =
    FutureProvider<Set<String>>(
      profileIdsInUseFor,
      name: 'profileIdsInUseProvider',
    );
Future<Set<String>> profileIdsInUseFor(Ref ref) async {
  final categories = await ref.watch(categoriesStreamProvider.future);
  final agents = await ref
      .watch(agentRepositoryProvider)
      .getAllAgentIdentities();

  return profileIdsInUse(categories: categories, agents: agents);
}
