import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/features/sync/vector_clock.dart';

/// Shared Glados generators for project-shaped entities and links —
/// consumed by `journal_entities_test.dart` (the `JournalEntity.project`
/// variant), `entry_link_test.dart` (the `ProjectLink` variant), and
/// `project_data_test.dart` (status/date/text primitives).

enum GeneratedProjectStatusKind { open, active, onHold, completed, archived }

class GeneratedProjectEntry {
  const GeneratedProjectEntry({
    required this.idSlot,
    required this.dateSlot,
    required this.categorySlot,
    required this.deletedAtSlot,
    required this.privateSlot,
    required this.starredSlot,
    required this.title,
    required this.statusKind,
    required this.targetDateSlot,
  });

  final int idSlot;
  final int dateSlot;
  final int categorySlot;
  final int deletedAtSlot;
  final int privateSlot;
  final int starredSlot;
  final String title;
  final GeneratedProjectStatusKind statusKind;
  final int targetDateSlot;

  ProjectEntry get projectEntry {
    final date = projectEntityDate(dateSlot);
    return ProjectEntry(
      meta: Metadata(
        id: 'project-$idSlot',
        createdAt: date,
        updatedAt: projectEntityDate(dateSlot + 1),
        dateFrom: date,
        dateTo: projectEntityDate(dateSlot + 2),
        categoryId: optionalProjectText(categorySlot, 'category'),
        vectorClock: vectorClockForSlot(idSlot),
        deletedAt: deletedAtSlot.isEven
            ? null
            : projectEntityDate(deletedAtSlot),
        private: optionalBoolForSlot(privateSlot),
        starred: optionalBoolForSlot(starredSlot),
      ),
      data: ProjectData(
        title: title,
        status: projectStatusOf(statusKind, idSlot, dateSlot),
        dateFrom: date,
        dateTo: projectEntityDate(dateSlot + 2),
        targetDate: targetDateSlot.isEven
            ? null
            : projectEntityDate(targetDateSlot),
      ),
    );
  }

  @override
  String toString() {
    return 'GeneratedProjectEntry('
        'idSlot: $idSlot, '
        'dateSlot: $dateSlot, '
        'categorySlot: $categorySlot, '
        'deletedAtSlot: $deletedAtSlot, '
        'privateSlot: $privateSlot, '
        'starredSlot: $starredSlot, '
        'title: "$title", '
        'statusKind: $statusKind, '
        'targetDateSlot: $targetDateSlot)';
  }
}

class GeneratedProjectLink {
  const GeneratedProjectLink({
    required this.idSlot,
    required this.fromSlot,
    required this.toSlot,
    required this.dateSlot,
    required this.vectorClockSlot,
    required this.hiddenSlot,
    required this.collapsedSlot,
  });

  final int idSlot;
  final int fromSlot;
  final int toSlot;
  final int dateSlot;
  final int vectorClockSlot;
  final int hiddenSlot;
  final int collapsedSlot;

  ProjectLink get link =>
      EntryLink.project(
            id: 'project-link-$idSlot',
            fromId: 'project-$fromSlot',
            toId: 'task-$toSlot',
            createdAt: projectEntityDate(dateSlot),
            updatedAt: projectEntityDate(dateSlot + 1),
            vectorClock: vectorClockForSlot(vectorClockSlot),
            hidden: optionalBoolForSlot(hiddenSlot),
            collapsed: optionalBoolForSlot(collapsedSlot),
          )
          as ProjectLink;

  @override
  String toString() {
    return 'GeneratedProjectLink('
        'idSlot: $idSlot, '
        'fromSlot: $fromSlot, '
        'toSlot: $toSlot, '
        'dateSlot: $dateSlot, '
        'vectorClockSlot: $vectorClockSlot, '
        'hiddenSlot: $hiddenSlot, '
        'collapsedSlot: $collapsedSlot)';
  }
}

extension AnyProjectEntity on glados.Any {
  glados.Generator<String> get _projectEntityText =>
      glados.AnyUtils(this).choose(const [
        '',
        'Project',
        'Project with spaces',
        'Project "quoted"',
        r'Project \ slash',
      ]);

  glados.Generator<GeneratedProjectStatusKind> get _projectStatusKind =>
      glados.AnyUtils(this).choose(GeneratedProjectStatusKind.values);

  glados.Generator<GeneratedProjectEntry> get generatedProjectEntry =>
      glados.CombinableAny(this).combine9(
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 40),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        _projectEntityText,
        _projectStatusKind,
        glados.IntAnys(this).intInRange(0, 240),
        (
          int idSlot,
          int dateSlot,
          int categorySlot,
          int deletedAtSlot,
          int privateSlot,
          int starredSlot,
          String title,
          GeneratedProjectStatusKind statusKind,
          int targetDateSlot,
        ) => GeneratedProjectEntry(
          idSlot: idSlot,
          dateSlot: dateSlot,
          categorySlot: categorySlot,
          deletedAtSlot: deletedAtSlot,
          privateSlot: privateSlot,
          starredSlot: starredSlot,
          title: title,
          statusKind: statusKind,
          targetDateSlot: targetDateSlot,
        ),
      );

  glados.Generator<GeneratedProjectLink> get generatedProjectLink =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 80),
        glados.IntAnys(this).intInRange(0, 240),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        glados.IntAnys(this).intInRange(0, 20),
        (
          int idSlot,
          int fromSlot,
          int toSlot,
          int dateSlot,
          int vectorClockSlot,
          int hiddenSlot,
          int collapsedSlot,
        ) => GeneratedProjectLink(
          idSlot: idSlot,
          fromSlot: fromSlot,
          toSlot: toSlot,
          dateSlot: dateSlot,
          vectorClockSlot: vectorClockSlot,
          hiddenSlot: hiddenSlot,
          collapsedSlot: collapsedSlot,
        ),
      );
}

ProjectStatus projectStatusOf(
  GeneratedProjectStatusKind kind,
  int idSlot,
  int dateSlot,
) {
  final id = 'status-$idSlot';
  final date = projectEntityDate(dateSlot);
  return switch (kind) {
    GeneratedProjectStatusKind.open => ProjectStatus.open(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
    GeneratedProjectStatusKind.active => ProjectStatus.active(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
    GeneratedProjectStatusKind.onHold => ProjectStatus.onHold(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
      reason: 'reason-$idSlot',
    ),
    GeneratedProjectStatusKind.completed => ProjectStatus.completed(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
    GeneratedProjectStatusKind.archived => ProjectStatus.archived(
      id: id,
      createdAt: date,
      utcOffset: idSlot,
    ),
  };
}

DateTime projectEntityDate(int slot) {
  return DateTime.utc(
    2024 + (slot % 4),
    (slot % 12) + 1,
    (slot % 28) + 1,
    slot % 24,
    slot % 60,
  );
}

String? optionalProjectText(int slot, String prefix) {
  return switch (slot % 4) {
    0 => null,
    1 => '$prefix-$slot',
    2 => '$prefix "$slot"',
    _ => '$prefix \\ $slot',
  };
}

VectorClock? vectorClockForSlot(int slot) {
  if (slot % 4 == 0) {
    return null;
  }

  return VectorClock({
    'host-${slot % 3}': slot + 1,
    'shared': slot % 7,
  });
}

bool? optionalBoolForSlot(int slot) {
  return switch (slot % 3) {
    0 => null,
    1 => true,
    _ => false,
  };
}
