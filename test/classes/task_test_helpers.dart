import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/change_source.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/task.dart';

// ---------------------------------------------------------------------------
// Glados generator helpers for TaskStatus and TaskData.
// ---------------------------------------------------------------------------

enum GeneratedTaskStatusKind {
  open,
  inProgress,
  groomed,
  blocked,
  onHold,
  done,
  rejected,
}

class GeneratedTaskStatus {
  const GeneratedTaskStatus({
    required this.kind,
    required this.idSlot,
    required this.dateSlot,
    required this.utcOffset,
    required this.timezoneSlot,
    required this.reasonSlot,
    required this.hasGeo,
  });

  final GeneratedTaskStatusKind kind;
  final int idSlot;
  final int dateSlot;
  final int utcOffset;
  final int timezoneSlot;
  final int reasonSlot;
  final bool hasGeo;

  TaskStatus get status {
    final id = 'status-$idSlot';
    final createdAt = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
    );
    final tz = timezoneSlot.isEven ? null : 'Europe/Berlin';
    final geo = hasGeo
        ? Geolocation(
            createdAt: createdAt,
            latitude: (idSlot % 180) - 90.0,
            longitude: (idSlot % 360) - 180.0,
            geohashString: 'u281z',
          )
        : null;
    final reason = 'reason-$reasonSlot';

    return switch (kind) {
      GeneratedTaskStatusKind.open => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      GeneratedTaskStatusKind.inProgress => TaskStatus.inProgress(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      GeneratedTaskStatusKind.groomed => TaskStatus.groomed(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      GeneratedTaskStatusKind.blocked => TaskStatus.blocked(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        reason: reason,
        timezone: tz,
        geolocation: geo,
      ),
      GeneratedTaskStatusKind.onHold => TaskStatus.onHold(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        reason: reason,
        timezone: tz,
        geolocation: geo,
      ),
      GeneratedTaskStatusKind.done => TaskStatus.done(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
      GeneratedTaskStatusKind.rejected => TaskStatus.rejected(
        id: id,
        createdAt: createdAt,
        utcOffset: utcOffset,
        timezone: tz,
        geolocation: geo,
      ),
    };
  }

  @override
  String toString() =>
      'GeneratedTaskStatus(kind: $kind, idSlot: $idSlot, '
      'dateSlot: $dateSlot, utcOffset: $utcOffset)';
}

class GeneratedTaskData {
  const GeneratedTaskData({
    required this.statusKind,
    required this.idSlot,
    required this.dateSlot,
    required this.titleSlot,
    required this.prioritySlot,
    required this.languageSourceSlot,
    required this.optionalsSlot,
  });

  final GeneratedTaskStatusKind statusKind;
  final int idSlot;
  final int dateSlot;
  final int titleSlot;
  final int prioritySlot;
  final int languageSourceSlot;
  final int optionalsSlot;

  TaskStatus hMakeStatus(String id) {
    final createdAt = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
    );
    return switch (statusKind) {
      GeneratedTaskStatusKind.open => TaskStatus.open(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      GeneratedTaskStatusKind.inProgress => TaskStatus.inProgress(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      GeneratedTaskStatusKind.groomed => TaskStatus.groomed(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      GeneratedTaskStatusKind.blocked => TaskStatus.blocked(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
        reason: 'blocked-$idSlot',
      ),
      GeneratedTaskStatusKind.onHold => TaskStatus.onHold(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
        reason: 'onhold-$idSlot',
      ),
      GeneratedTaskStatusKind.done => TaskStatus.done(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
      GeneratedTaskStatusKind.rejected => TaskStatus.rejected(
        id: id,
        createdAt: createdAt,
        utcOffset: 0,
      ),
    };
  }

  TaskData get data {
    final dateFrom = DateTime.utc(
      2024,
      (dateSlot % 12) + 1,
      (dateSlot % 28) + 1,
    );
    final status = hMakeStatus('status-$idSlot');
    final history = optionalsSlot.isEven ? <TaskStatus>[] : [status];
    final priority =
        TaskPriority.values[prioritySlot % TaskPriority.values.length];
    final langSource = languageSourceSlot.isOdd
        ? ChangeSource.agent
        : ChangeSource.user;
    final langCode = optionalsSlot % 3 == 0 ? null : 'lang-$optionalsSlot';
    final suppressed = optionalsSlot % 4 == 0
        ? null
        : <String>{'lbl-$optionalsSlot'};

    return TaskData(
      status: status,
      dateFrom: dateFrom,
      dateTo: dateFrom,
      statusHistory: history,
      title: 'Title $titleSlot',
      languageCode: langCode,
      languageSource: langSource,
      priority: priority,
      aiSuppressedLabelIds: suppressed,
    );
  }

  @override
  String toString() =>
      'GeneratedTaskData(statusKind: $statusKind, idSlot: $idSlot, '
      'titleSlot: $titleSlot, prioritySlot: $prioritySlot)';
}

extension AnyTaskClasses on glados.Any {
  glados.Generator<GeneratedTaskStatusKind> get _taskStatusKind =>
      glados.AnyUtils(this).choose(GeneratedTaskStatusKind.values);

  glados.Generator<GeneratedTaskStatus> get generatedTaskStatus =>
      glados.CombinableAny(this).combine7(
        _taskStatusKind,
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(-720, 720),
        glados.IntAnys(this).intInRange(0, 10),
        glados.IntAnys(this).intInRange(0, 10),
        glados.any.bool,
        (kind, idSlot, dateSlot, utcOffset, timezoneSlot, reasonSlot, hasGeo) =>
            GeneratedTaskStatus(
              kind: kind,
              idSlot: idSlot,
              dateSlot: dateSlot,
              utcOffset: utcOffset,
              timezoneSlot: timezoneSlot,
              reasonSlot: reasonSlot,
              hasGeo: hasGeo,
            ),
      );

  glados.Generator<GeneratedTaskData> get generatedTaskData =>
      glados.CombinableAny(this).combine7(
        _taskStatusKind,
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 50),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 1),
        glados.IntAnys(this).intInRange(0, 15),
        (
          statusKind,
          idSlot,
          dateSlot,
          titleSlot,
          prioritySlot,
          languageSourceSlot,
          optionalsSlot,
        ) => GeneratedTaskData(
          statusKind: statusKind,
          idSlot: idSlot,
          dateSlot: dateSlot,
          titleSlot: titleSlot,
          prioritySlot: prioritySlot,
          languageSourceSlot: languageSourceSlot,
          optionalsSlot: optionalsSlot,
        ),
      );
}
