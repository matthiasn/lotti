import 'package:flutter/foundation.dart';

/// How a day turned out, in the user's own judgement.
///
/// [improving] is the case a three-way verdict could not express: some of it
/// was missed, but the day moved the right way. Without it a day like that
/// had to be filed as [mixed] alongside days that simply stalled, and the
/// strip could not show "not perfect, but on the right track".
///
/// Ordered best to worst. Persisted by `name`, so the order is free to change
/// but the names are not.
enum GoalAssessmentRating { met, improving, mixed, missed }

enum GoalAssessmentProvenance { ratedByUser, suggestedAndAccepted }

@immutable
class GoalAssessmentRecord {
  const GoalAssessmentRecord({
    required this.id,
    required this.day,
    required this.specVersionId,
    required this.rating,
    required this.createdAt,
    required this.provenance,
    this.note,
    this.dimensionRatings = const {},
    this.suggestedBy,
  });

  final String id;
  final DateTime day;
  final String specVersionId;
  final GoalAssessmentRating rating;
  final String? note;
  final Map<String, GoalAssessmentRating> dimensionRatings;
  final DateTime createdAt;
  final GoalAssessmentProvenance provenance;
  final String? suggestedBy;
}
