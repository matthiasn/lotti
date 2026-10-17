import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Writes a task titled [title], due [due], in [categoryId] and with the
/// privacy of [inheritContextFrom], and returns it — or null when nothing
/// was written.
typedef PersonCaptureCreateTask =
    Future<Task?> Function({
      required String title,
      required DateTime? due,
      required String? categoryId,
      required String inheritContextFrom,
    });

/// Writes a plain link from [fromId] to [toId]; answers whether it landed.
typedef PersonCaptureLink =
    Future<bool> Function({required String fromId, required String toId});

/// Files what the user accepted from a spoken capture about a person
/// (plan 2026-10-15, *Speak your mind*, step 5). The capture is already a
/// voice note on the person's timeline; filing makes it what it was about.
///
/// - A **check-in** is written with the summary as its narrative and the
///   recording attached, and the voice note leaves the timeline: the
///   check-in holds it now, so the timeline shows it once.
/// - A **note** is the voice note itself — its transcript is already its
///   words — while the recording is still on the timeline; a second note,
///   or any note once a check-in took the recording, is written as a note of
///   its own.
/// - A **meeting** is a planned event on the timeline; a **task** is linked
///   to the person as any task. Both link to the recording, so either one
///   leads back to what was said.
///
/// Check-ins go first, since they decide where the recording lives. Where it
/// lives is read from the timeline, not remembered, so a retry of what an
/// earlier filing handed back decides the same way. Each item is filed on
/// its own: one that could not be written is handed back rather than
/// abandoning the rest. Once an item is written it counts as filed whatever
/// happens to the links around it, since a retry would write it twice.
class PersonCaptureFiler {
  PersonCaptureFiler({
    required this._relationships,
    required this._timeline,
    required this._createTask,
    required this._link,
    this._logger,
  });

  final RelationshipRepository _relationships;
  final PersonTimelineRepository _timeline;
  final PersonCaptureCreateTask _createTask;
  final PersonCaptureLink _link;
  final DomainLogger? _logger;

  /// Files [items] for [person] from voice note [audioId], spoken at [now].
  /// Returns the items that could not be filed, in their order; empty when
  /// all were.
  Future<List<PersonCaptureItem>> file({
    required RelationshipEntry person,
    required String audioId,
    required List<PersonCaptureItem> items,
    required DateTime now,
  }) async {
    final ordered = [
      ...items.whereType<PersonCaptureCheckIn>(),
      ...items.where((item) => item is! PersonCaptureCheckIn),
    ];
    final unfiled = <PersonCaptureItem>{};
    // Whether the recording is still the voice note on the timeline — false
    // when an earlier filing gave it to a check-in.
    var recordingOnTimeline = await _timeline.isOnTimeline(
      personId: person.meta.id,
      entryId: audioId,
    );
    var voiceNoteIsANote = false;
    for (final item in ordered) {
      try {
        final filed = switch (item) {
          final PersonCaptureCheckIn checkIn => await _checkIn(
            person,
            audioId,
            checkIn,
            now: now,
            attach: recordingOnTimeline,
            onMoved: () => recordingOnTimeline = false,
          ),
          // The first note while the recording is on the timeline is the
          // voice note itself; its words are already there.
          PersonCaptureNote() when recordingOnTimeline && !voiceNoteIsANote =>
            voiceNoteIsANote = true,
          PersonCaptureNote(:final text) =>
            await _timeline.createNote(person: person, text: text) != null,
          final PersonCaptureMeeting meeting => await _meeting(
            person,
            audioId,
            meeting,
            now: now,
          ),
          final PersonCaptureTask task => await _task(person, audioId, task),
        };
        if (!filed) unfiled.add(item);
      } catch (error, stackTrace) {
        _logger?.error(
          LogDomain.persistence,
          error,
          stackTrace: stackTrace,
          subDomain: 'personCaptureFiler',
          message: 'filing a ${item.runtimeType} failed',
        );
        unfiled.add(item);
      }
    }
    return [
      for (final item in items)
        if (unfiled.contains(item)) item,
    ];
  }

  Future<bool> _checkIn(
    RelationshipEntry person,
    String audioId,
    PersonCaptureCheckIn checkIn, {
    required DateTime now,
    required bool attach,
    required void Function() onMoved,
  }) async {
    final duration = checkIn.duration ?? Duration.zero;
    // Untimed, a conversation ended when it was spoken about.
    final started = checkIn.startedAt ?? now.subtract(duration);
    final created = await _relationships.createCheckIn(
      data: CheckInData(
        relationshipId: person.meta.id,
        interactionType: checkIn.interactionType,
        topics: checkIn.topics,
        payAttentionTo: checkIn.bringUp,
        avoid: checkIn.avoid,
      ),
      entryText: EntryText(plainText: checkIn.summary),
      dateFrom: started,
      dateTo: started.add(duration),
    );
    if (created == null) return false;
    if (!attach) return true;
    // The check-in is saved: a recording that will not attach stays the
    // voice note it is, and the check-in still counts as filed.
    await _afterWrite('attaching the recording to a check-in', () async {
      final attached = await _relationships.attachEntriesToCheckIn(
        checkInId: created.meta.id,
        entryIds: [audioId],
      );
      if (!attached) return;
      onMoved();
      await _timeline.removeFromTimeline(
        personId: person.meta.id,
        entryId: audioId,
      );
    });
    return true;
  }

  /// A step after an item was written: logged when it fails, never a
  /// reason to hand the written item back.
  Future<void> _afterWrite(String what, Future<void> Function() step) async {
    try {
      await step();
    } catch (error, stackTrace) {
      _logger?.error(
        LogDomain.persistence,
        error,
        stackTrace: stackTrace,
        subDomain: 'personCaptureFiler',
        message: '$what failed after the item was filed',
      );
    }
  }

  Future<bool> _meeting(
    RelationshipEntry person,
    String audioId,
    PersonCaptureMeeting meeting, {
    required DateTime now,
  }) async {
    final created = await _timeline.createMeeting(
      person: person,
      title: meeting.title,
      start: meeting.start ?? personMeetingDefaultStart(now),
      duration: meeting.duration ?? personMeetingDefaultDuration,
    );
    if (created == null) return false;
    await _afterWrite(
      'linking a meeting to its recording',
      () => _link(fromId: created.meta.id, toId: audioId),
    );
    return true;
  }

  Future<bool> _task(
    RelationshipEntry person,
    String audioId,
    PersonCaptureTask task,
  ) async {
    final created = await _createTask(
      title: task.title,
      due: task.due,
      categoryId: person.meta.categoryId,
      inheritContextFrom: person.meta.id,
    );
    if (created == null) return false;
    // Written is filed: handed back, a task whose link failed would be
    // written a second time by the retry. The miss is logged instead.
    await _afterWrite('linking a task to its person', () async {
      final linked = await _relationships.linkTask(
        relationshipId: person.meta.id,
        taskId: created.meta.id,
      );
      if (!linked) {
        _logger?.log(
          LogDomain.persistence,
          'a filed task could not be linked to its person',
          subDomain: 'personCaptureFiler',
        );
      }
    });
    await _afterWrite(
      'linking a task to its recording',
      () => _link(fromId: created.meta.id, toId: audioId),
    );
    return true;
  }
}
