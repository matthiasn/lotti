import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'automatic_image_analysis_trigger.g.dart';

/// Helper class to handle automatic image analysis after image import.
///
/// When an image is added to a task (via drag-and-drop, paste, or menu import),
/// this trigger checks if the category has automatic image analysis configured
/// and triggers the analysis if so.
class AutomaticImageAnalysisTrigger {
  AutomaticImageAnalysisTrigger({
    required this.ref,
    required this.loggingService,
    required this.categoryRepository,
  });

  final Ref ref;
  final LoggingService loggingService;
  final CategoryRepository categoryRepository;

  /// Triggers automatic image analysis if configured for the category.
  ///
  /// Parameters:
  /// - [imageEntryId]: The ID of the newly created image entry
  /// - [categoryId]: The category of the image (from linked task or direct)
  /// - [linkedTaskId]: Optional task ID if image is linked to a task
  ///
  /// Does nothing if:
  /// - categoryId is null
  /// - Category has no automatic prompts configured
  /// - Category has no image analysis prompts configured
  /// - No platform-compatible prompts are available
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    required String? categoryId,
    String? linkedTaskId,
  }) async {
    if (categoryId == null) return;

    try {
      final category = await categoryRepository.getCategoryById(categoryId);
      final imageAnalysisPromptIds =
          category?.automaticPrompts?[AiResponseType.imageAnalysis];

      if (imageAnalysisPromptIds == null || imageAnalysisPromptIds.isEmpty) {
        return;
      }

      // Get the first available prompt for the current platform
      final capabilityFilter = ref.read(promptCapabilityFilterProvider);
      final availablePrompt = await capabilityFilter.getFirstAvailablePrompt(
        imageAnalysisPromptIds,
      );

      if (availablePrompt == null) {
        loggingService.captureEvent(
          'No available image analysis prompts for current platform',
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        );
        return;
      }

      loggingService.captureEvent(
        'Triggering automatic image analysis for image $imageEntryId',
        domain: 'automatic_image_analysis_trigger',
        subDomain: 'triggerAutomaticImageAnalysis',
      );

      await ref.read(
        triggerNewInferenceProvider((
          entityId: imageEntryId,
          promptId: availablePrompt.id,
          linkedEntityId: linkedTaskId,
        )).future,
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
    categoryRepository: ref.read(categoryRepositoryProvider),
  );
}
