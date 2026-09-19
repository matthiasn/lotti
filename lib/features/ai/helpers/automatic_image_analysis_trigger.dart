import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Helper class to handle automatic image analysis after image import.
///
/// Uses the profile-driven automation path exclusively. When a task has an
/// agent with a profile that includes an image analysis skill, the skill is
/// invoked via [SkillInferenceRunner]. Otherwise, nothing happens.
class AutomaticImageAnalysisTrigger {
  AutomaticImageAnalysisTrigger({
    required this.ref,
    required this.loggingService,
  });

  final Ref ref;
  final DomainLogger loggingService;

  /// Triggers automatic image analysis via profile-driven automation.
  ///
  /// The profile is resolved for [subjectId], defaulting to [linkedTaskId] —
  /// the task the picture belongs to. A subject whose agent profile (or the
  /// profile it inherits from its category) assigns an image-analysis skill
  /// gets one; otherwise this logs and returns silently. [subjectId] is what
  /// lets a picture belonging to something other than a task — a person's
  /// check-in — resolve against that owner instead.
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    String? linkedTaskId,
    String? subjectId,
  }) async {
    try {
      final subject = subjectId ?? linkedTaskId;
      if (subject == null) {
        loggingService.log(
          LogDomain.ai,
          'No subject for image $imageEntryId — skipping automatic '
          'image analysis',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      final automationService = ref.read(profileAutomationServiceProvider);
      final result = await automationService.tryAnalyzeImage(
        subjectId: subject,
      );

      if (!result.handled) {
        loggingService.log(
          LogDomain.ai,
          'Profile automation did not handle image analysis for '
          'subject $subject',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      loggingService.log(
        LogDomain.ai,
        'Profile-driven image analysis for subject $subject '
        'using skill "${result.skill!.id}"',
        subDomain: 'triggerAutomaticImageAnalysis',
      );

      final runner = ref.read(skillInferenceRunnerProvider);
      await runner.runImageAnalysis(
        imageEntryId: imageEntryId,
        automationResult: result,
        linkedTaskId: linkedTaskId,
      );
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'triggerAutomaticImageAnalysis',
      );
    }
  }
}

/// Provider for the automatic image analysis trigger helper.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.
final automaticImageAnalysisTriggerProvider =
    Provider<AutomaticImageAnalysisTrigger>(
      automaticImageAnalysisTrigger,
      name: 'automaticImageAnalysisTriggerProvider',
    );
AutomaticImageAnalysisTrigger automaticImageAnalysisTrigger(Ref ref) {
  return AutomaticImageAnalysisTrigger(
    ref: ref,
    loggingService: getIt<DomainLogger>(),
  );
}
