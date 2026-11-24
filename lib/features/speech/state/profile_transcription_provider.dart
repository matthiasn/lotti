import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/ai/skill_type.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_profile_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';

/// Whether a subject has profile-driven transcription available — what
/// decides if a take linked to it is transcribed, and so whether the
/// receipt says *Transcribing*.
///
/// Re-evaluates when profiles change (via [inferenceProfileControllerProvider])
/// so that edits to automation toggles are immediately reflected in the UI.
/// Uses the pure capability check rather than the execution path to avoid
/// side effects during render-time reads.
final FutureProviderFamily<bool, String> hasProfileTranscriptionProvider =
    FutureProvider.autoDispose.family<bool, String>(
      hasProfileTranscription,
      name: 'hasProfileTranscriptionProvider',
    );
Future<bool> hasProfileTranscription(Ref ref, String taskId) async {
  // Watch the profiles stream so this provider invalidates when any
  // profile is edited. Without this, the result would be stale after
  // a profile automation toggle change.
  ref.watch(inferenceProfileControllerProvider);

  final service = ref.watch(profileAutomationServiceProvider);
  return service.hasAutomatedSkillType(
    subjectId: taskId,
    skillType: SkillType.transcription,
  );
}
