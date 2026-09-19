import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';

/// Analyses a photo added to a check-in the way a photo dropped on a task is
/// analysed: through profile automation, so it runs only where the person —
/// or the category they inherit from — has an image-analysis skill assigned,
/// and not at all otherwise.
///
/// The person is the subject, not the check-in: their agent's profile is the
/// one that decides, and it falls back to their category. A description is
/// evidence the agent reads (ADR 0062 Decision 2), so the check-in is saved
/// again once one lands, exactly as a late transcript does it (Decision 3).
class CheckInPhotoAnalysisTrigger extends AutomaticImageAnalysisTrigger {
  CheckInPhotoAnalysisTrigger({
    required super.ref,
    required super.loggingService,
    required this._relationships,
    required this._journalDb,
  });

  final RelationshipRepository _relationships;
  final JournalDb _journalDb;

  /// [linkedTaskId] carries the check-in the photo was added to — what the
  /// import links the picture to.
  @override
  Future<void> triggerAutomaticImageAnalysis({
    required String imageEntryId,
    String? linkedTaskId,
    String? subjectId,
  }) async {
    final checkInId = linkedTaskId;
    if (checkInId == null) return;
    final String relationshipId;
    try {
      final checkIn = await _journalDb.journalEntityById(checkInId);
      if (checkIn is! CheckInEntry) return;
      relationshipId = checkIn.data.relationshipId;
    } catch (exception, stackTrace) {
      loggingService.error(
        LogDomain.ai,
        exception,
        stackTrace: stackTrace,
        subDomain: 'checkInPhotoAnalysis',
      );
      return;
    }

    await super.triggerAutomaticImageAnalysis(
      imageEntryId: imageEntryId,
      subjectId: relationshipId,
    );

    // Whether or not a profile handled it, the touch is cheap and only a
    // written description changes what the next briefing reads.
    await _relationships.touchCheckInsHolding(imageEntryId);
  }
}

/// The trigger the check-in photo importer hands to the import.
final checkInPhotoAnalysisTriggerProvider =
    Provider<CheckInPhotoAnalysisTrigger>(
      (ref) => CheckInPhotoAnalysisTrigger(
        ref: ref,
        loggingService: getIt<DomainLogger>(),
        relationships: ref.watch(relationshipRepositoryProvider),
        journalDb: getIt<JournalDb>(),
      ),
      name: 'checkInPhotoAnalysisTriggerProvider',
    );
