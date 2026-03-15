import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automatic_image_analysis_trigger.g.dart';

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
  final LoggingService loggingService;

  /// Triggers automatic image analysis via profile-driven automation.
  ///
  /// Requires a [linkedTaskId] whose agent has a profile with an image
  /// analysis skill assigned. If no profile handles it, logs and returns
  /// silently.
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    String? linkedTaskId,
  }) async {
    try {
      if (linkedTaskId == null) {
        loggingService.captureEvent(
          'No linked task for image $imageEntryId — skipping automatic '
          'image analysis',
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      final automationService = ref.read(profileAutomationServiceProvider);
      final result = await automationService.tryAnalyzeImage(
        taskId: linkedTaskId,
      );

      if (!result.handled) {
        loggingService.captureEvent(
          'Profile automation did not handle image analysis for '
          'task $linkedTaskId',
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      loggingService.captureEvent(
        'Profile-driven image analysis for task $linkedTaskId '
        'using skill "${result.skill!.id}"',
        domain: 'automatic_image_analysis_trigger',
        subDomain: 'triggerAutomaticImageAnalysis',
      );

      final runner = ref.read(skillInferenceRunnerProvider);
      await runner.runImageAnalysis(
        imageEntryId: imageEntryId,
        automationResult: result,
        linkedTaskId: linkedTaskId,
      );
    } catch (exception, stackTrace) {
      loggingService.captureException(
        exception,
        domain: 'automatic_image_analysis_trigger',
        subDomain: 'triggerAutomaticImageAnalysis',
        stackTrace: stackTrace,
      );
    }
  }
}

/// Provider for the automatic image analysis trigger helper.
///
/// Uses keepAlive to prevent disposal during async operations.
/// The trigger stores a Ref and uses it in async operations, so it must
/// remain valid throughout the inference lifecycle.
@Riverpod(keepAlive: true)
AutomaticImageAnalysisTrigger automaticImageAnalysisTrigger(Ref ref) {
  return AutomaticImageAnalysisTrigger(
    ref: ref,
    loggingService: getIt<LoggingService>(),
  );
}
