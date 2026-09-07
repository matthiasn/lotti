import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';

/// Deterministic generator parameters. Distances are world metres, independent
/// of display density. Alternative layouts can vary these inputs without
/// changing persisted project/task data or the renderer.
class ProjectWorldConfig {
  const ProjectWorldConfig({
    this.seed = 0,
    this.minimumPlotSpacing = 6,
    this.completedSetback = 12,
    this.weeksPerRow = 4,
    this.ambientCreatures = 24,
  }) : assert(minimumPlotSpacing > 0, 'plots need positive spacing'),
       assert(completedSetback >= 0, 'setback cannot be negative'),
       assert(weeksPerRow > 0, 'a row must contain weeks'),
       assert(ambientCreatures >= 0, 'creature budget cannot be negative');

  final int seed;
  final double minimumPlotSpacing;
  final double completedSetback;
  final int weeksPerRow;
  final int ambientCreatures;

  StreetLayout layoutFor(String projectId) => StreetLayout(
    projectSeed: stableHash('$projectId:$seed'),
    minimumPlotSpacing: minimumPlotSpacing,
    completedSetback: completedSetback,
    foldEvery: weeksPerRow,
    scaleBillboardsByPriority: true,
  );
}

/// Produces the complete CPU scene description from one scoped snapshot.
/// The project's start anchors week markers even when older tasks arrive later.
/// Membership/privacy filtering belongs to PlazaRepository, before generation.
PlazaWorld generateProjectWorld({
  required ProjectEntry project,
  required List<PlazaTask> tasks,
  required DateTime now,
  Map<String, String> categoryLabels = const {},
  ProjectWorldConfig config = const ProjectWorldConfig(),
  PlazaCopy? copy,
}) => PlazaWorld(
  tasks: tasks,
  now: now,
  projectLabel: project.data.title,
  epoch: project.data.dateFrom,
  categoryLabels: categoryLabels,
  layout: config.layoutFor(project.meta.id),
  ambientCreatures: config.ambientCreatures,
  copy: copy,
);
