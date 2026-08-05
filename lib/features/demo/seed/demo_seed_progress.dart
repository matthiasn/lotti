/// Stages exposed while an inactive demo world is being prepared.
enum DemoSeedPhase {
  preparing,
  downloadingMedia,
  writingContent,
  activating,
}

/// Immutable progress snapshot for the blocking demo-entry surface.
class DemoSeedProgress {
  const DemoSeedProgress._({
    required this.phase,
    this.completed = 0,
    this.total = 0,
  });

  const DemoSeedProgress.preparing() : this._(phase: DemoSeedPhase.preparing);

  const DemoSeedProgress.downloadingMedia({
    required int completed,
    required int total,
  }) : this._(
         phase: DemoSeedPhase.downloadingMedia,
         completed: completed,
         total: total,
       );

  const DemoSeedProgress.writingContent()
    : this._(phase: DemoSeedPhase.writingContent);

  const DemoSeedProgress.activating() : this._(phase: DemoSeedPhase.activating);

  final DemoSeedPhase phase;
  final int completed;
  final int total;

  /// Completed fraction for the determinate media phase; otherwise `null`.
  double? get fraction {
    if (phase != DemoSeedPhase.downloadingMedia || total <= 0) return null;
    return (completed / total).clamp(0, 1);
  }
}

typedef DemoSeedProgressCallback = void Function(DemoSeedProgress progress);
