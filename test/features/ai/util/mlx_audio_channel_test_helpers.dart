import 'package:glados/glados.dart' as glados;


enum GeneratedProgressStatusShape {
  installed,
  downloading,
  notInstalled,
  failed,
  unsupported,
  unknown,
}

class GeneratedDownloadProgressScenario {
  const GeneratedDownloadProgressScenario({
    required this.statusShape,
    required this.completedUnitCount,
    required this.totalUnitCount,
    required this.progressPermille,
    required this.includeByteCounts,
    required this.includeProgress,
  });

  final GeneratedProgressStatusShape statusShape;
  final int completedUnitCount;
  final int totalUnitCount;
  final int progressPermille;
  final bool includeByteCounts;
  final bool includeProgress;

  String get statusValue => switch (statusShape) {
    GeneratedProgressStatusShape.installed => 'installed',
    GeneratedProgressStatusShape.downloading => 'downloading',
    GeneratedProgressStatusShape.notInstalled => 'notInstalled',
    GeneratedProgressStatusShape.failed => 'failed',
    GeneratedProgressStatusShape.unsupported => 'unsupported',
    GeneratedProgressStatusShape.unknown => 'generated-unknown-status',
  };

  double get progressValue => progressPermille / 1000;

  Map<String, Object?> get map => {
    'modelId': 'mlx-community/generated',
    'status': statusValue,
    if (includeByteCounts) 'completedUnitCount': completedUnitCount,
    if (includeByteCounts) 'totalUnitCount': totalUnitCount,
    if (includeProgress) 'progress': progressValue,
  };

  double? get expectedNormalizedProgress {
    if (statusShape == GeneratedProgressStatusShape.installed) {
      return 1;
    }
    if (includeByteCounts && totalUnitCount > 0) {
      return (completedUnitCount / totalUnitCount).clamp(0, 1).toDouble();
    }
    if (includeProgress && progressValue > 0) {
      return progressValue.clamp(0, 1).toDouble();
    }
    return null;
  }

  int? get expectedPercentComplete {
    final normalized = expectedNormalizedProgress;
    if (normalized == null) return null;
    return (normalized * 100).clamp(0, 100).floor();
  }

  bool get expectedHasMeasuredProgress => expectedNormalizedProgress != null;

  @override
  String toString() {
    return 'GeneratedDownloadProgressScenario('
        'statusShape: $statusShape, '
        'completedUnitCount: $completedUnitCount, '
        'totalUnitCount: $totalUnitCount, '
        'progressPermille: $progressPermille, '
        'includeByteCounts: $includeByteCounts, '
        'includeProgress: $includeProgress)';
  }
}

extension AnyDownloadProgressScenario on glados.Any {
  glados.Generator<GeneratedProgressStatusShape> get progressStatusShape =>
      glados.AnyUtils(this).choose(GeneratedProgressStatusShape.values);

  glados.Generator<GeneratedDownloadProgressScenario>
  get downloadProgressScenario => glados.CombinableAny(this).combine6(
    progressStatusShape,
    glados.IntAnys(this).intInRange(-1000, 2000),
    glados.IntAnys(this).intInRange(-100, 1000),
    glados.IntAnys(this).intInRange(-250, 1250),
    glados.BoolAny(this).bool,
    glados.BoolAny(this).bool,
    (
      GeneratedProgressStatusShape statusShape,
      int completedUnitCount,
      int totalUnitCount,
      int progressPermille,
      bool includeByteCounts,
      bool includeProgress,
    ) => GeneratedDownloadProgressScenario(
      statusShape: statusShape,
      completedUnitCount: completedUnitCount,
      totalUnitCount: totalUnitCount,
      progressPermille: progressPermille,
      includeByteCounts: includeByteCounts,
      includeProgress: includeProgress,
    ),
  );
}
