import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

/// What the photo import does with each picture added from a person's page:
/// puts it on the person's timeline (ADR 0138), then has it described where
/// the person's profile — or the category they inherit from — assigns an
/// image-analysis skill, exactly as a photo on a task is.
///
/// The import runs this once per picture it *created*, and passes the person
/// it was imported for as `linkedTaskId` — the id the import links the
/// picture to, which is also what gives a private person's photo the private
/// flag. That plain link alone would leave the photo off the timeline: a
/// person's plain links carry their avatar and banner too.
class PersonPhotoTimelineTrigger extends AutomaticImageAnalysisTrigger {
  PersonPhotoTimelineTrigger({
    required super.ref,
    required super.loggingService,
    required this._timeline,
  });

  final PersonTimelineRepository _timeline;

  @override
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    String? linkedTaskId,
    String? subjectId,
  }) async {
    final personId = linkedTaskId;
    if (personId == null) return;
    try {
      final added = await _timeline.addToTimeline(
        personId: personId,
        entryId: imageEntryId,
      );
      if (!added) {
        loggingService.error(
          LogDomain.persistence,
          'person photo timeline link rejected for $imageEntryId',
          subDomain: 'personPhotoTimeline',
        );
      }
    } catch (exception, stackTrace) {
      // Fire-and-forget: the importer never awaits this.
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'personPhotoTimeline',
      );
    }
    await super.triggerAutomaticImageAnalysis(
      imageEntryId: imageEntryId,
      subjectId: personId,
    );
  }
}

/// The trigger the person page's photo import hands to the import.
final personPhotoTimelineTriggerProvider = Provider<PersonPhotoTimelineTrigger>(
  (ref) => PersonPhotoTimelineTrigger(
    ref: ref,
    loggingService: ref.watch(domainLoggerProvider),
    timeline: ref.watch(personTimelineRepositoryProvider),
  ),
  name: 'personPhotoTimelineTriggerProvider',
);
