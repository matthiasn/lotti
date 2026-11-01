import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';

/// Dictation for the goal coached by the agent `agentId` — its chat and its
/// charter sheet — on the profile the goal's check-ins transcribe through:
/// its category's, else the Settings default. Null while no goal repository
/// is available, the same condition under which the goal has no surfaces.
final ProviderFamily<SubjectDictation?, String> goalDictationProvider =
    Provider.family<SubjectDictation?, String>((ref, agentId) {
      final goalId = ref.watch(goalRepositoryProvider)?.goalIdForAgent(agentId);
      return goalId == null
          ? null
          : ref.watch(subjectDictationProvider(goalId));
    }, name: 'goalDictationProvider');
