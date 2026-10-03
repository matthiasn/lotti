import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/agent_wake_cadence.dart';
import 'package:lotti/features/ai/state/ai_runtime_settings_controller.dart';
import 'package:lotti/providers/service_providers.dart';

/// The wake cadence a task in category `categoryId` follows when it has no
/// cadence of its own: the category's, else the app default.
///
/// The same resolution the wake orchestrator applies (see
/// [resolveAgentWakeCadence]), so a picker's "Same as category" names the
/// cadence that actually runs.
final ProviderFamily<AgentWakeCadence, String?>
inheritedTaskWakeCadenceProvider = Provider.autoDispose
    .family<AgentWakeCadence, String?>((ref, categoryId) {
      final category = categoryId == null
          ? null
          : ref
                .watch(entitiesCacheServiceProvider)
                ?.getCategoryById(categoryId);
      return resolveAgentWakeCadence(
        category: category?.agentWakeCadence,
        global: ref
            .watch(aiRuntimeSettingsControllerProvider)
            .defaultWakeCadence,
      );
    });
