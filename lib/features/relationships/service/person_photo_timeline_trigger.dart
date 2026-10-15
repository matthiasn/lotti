import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
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
///
/// A description is evidence the briefing reads, and it lands as an entry of
/// its own, after the photo: once one is written the photo is saved again,
/// so the agent sees the change — as the check-in photo trigger does.
class PersonPhotoTimelineTrigger extends AutomaticImageAnalysisTrigger {
  PersonPhotoTimelineTrigger({
    required super.ref,
    required super.loggingService,
    required this._timeline,
    required this._relationships,
  });

  final PersonTimelineRepository _timeline;
  final RelationshipRepository _relationships;

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

    // Only a written description changes what the next briefing reads; a
    // run that wrote none must not buy another inference.
    try {
      final described = await _relationships.getImageDescriptions({
        imageEntryId,
      });
      if (described.isEmpty) return;
      await _timeline.touch(imageEntryId);
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.persistence,
        exception,
        stackTrace: stackTrace,
        subDomain: 'personPhotoTimeline',
      );
    }
  }
}

/// The trigger the person page's photo import hands to the import.
final personPhotoTimelineTriggerProvider = Provider<PersonPhotoTimelineTrigger>(
  (ref) => PersonPhotoTimelineTrigger(
    ref: ref,
    loggingService: ref.watch(domainLoggerProvider),
    timeline: ref.watch(personTimelineRepositoryProvider),
    relationships: ref.watch(relationshipRepositoryProvider),
  ),
  name: 'personPhotoTimelineTriggerProvider',
);
