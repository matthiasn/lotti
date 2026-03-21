class ProjectAcceptedRecommendation {
  const ProjectAcceptedRecommendation({
    required this.title,
    this.rationale,
    this.priority,
  });

  final String title;
  final String? rationale;
  final String? priority;

  String get dedupKey =>
      '${title.trim().toLowerCase()}|'
      '${rationale?.trim().toLowerCase() ?? ''}|'
      '${priority?.trim().toUpperCase() ?? ''}';
}

List<ProjectAcceptedRecommendation> parseProjectAcceptedRecommendations(
  Object? rawSteps,
) {
  if (rawSteps is! List) return const [];

  final recommendations = <ProjectAcceptedRecommendation>[];
  final seenKeys = <String>{};

  for (final rawStep in rawSteps) {
    if (rawStep is! Map) continue;

    final title = rawStep['title'];
    if (title is! String || title.trim().isEmpty) continue;

    final rationale = rawStep['rationale'];
    final priority = rawStep['priority'];

    final recommendation = ProjectAcceptedRecommendation(
      title: title.trim(),
      rationale: rationale is String && rationale.trim().isNotEmpty
          ? rationale.trim()
          : null,
      priority: priority is String && priority.trim().isNotEmpty
          ? priority.trim().toUpperCase()
          : null,
    );

    if (!seenKeys.add(recommendation.dedupKey)) {
      continue;
    }

    recommendations.add(recommendation);
  }

  return recommendations;
}
