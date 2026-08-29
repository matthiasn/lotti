import 'package:flutter/foundation.dart';
import 'package:lotti/widgets/day_indicators/day_mark.dart';

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
  final DayVerdict rating;
  final String? note;
  final Map<String, DayVerdict> dimensionRatings;
  final DateTime createdAt;
  final DayVerdictProvenance provenance;
  final String? suggestedBy;
}
