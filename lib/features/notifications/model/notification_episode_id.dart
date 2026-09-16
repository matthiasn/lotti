import 'dart:convert';

import 'package:uuid/uuid.dart';

/// The deterministic id of one episode of one notification kind for one
/// subject.
///
/// A uuid v5 over the canonical JSON of `[kind, subjectId, episodeKey]` — the
/// scheme the task-suggestion id already uses — so two devices deriving the
/// same episode converge on one row without coordinating, and no two kinds
/// can collide on a shared subject id. [kind] is the variant's wire
/// discriminator (`NotificationEntity.type`), which pins the id to the union:
/// renaming a variant would already make every synced row of that kind
/// undecodable, so it cannot silently change ids either.
///
/// Identity is per **episode**, never per subject. The three lifecycle marks
/// are monotonic and cannot be cleared, so one row per subject would let an
/// August dismissal permanently silence September; an episode that moves on
/// mints a new id and retracts the old row instead.
String notificationEpisodeId({
  required String kind,
  required String subjectId,
  required String episodeKey,
}) => const Uuid().v5(
  Namespace.nil.value,
  jsonEncode(<String>[kind, subjectId, episodeKey]),
);
