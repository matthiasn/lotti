import 'package:flutter/foundation.dart';

enum GoalAssessmentRating { met, mixed, missed }

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
