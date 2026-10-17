import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';

/// Where a spoken capture about a person stands (plan 2026-10-15, *Speak
/// your mind*). From the moment it is recorded the capture is a voice note
/// on the person's timeline; every later phase only offers to file it as
/// something more specific, and every way out short of filing leaves it the
/// voice note it already is.
///
/// ```text
/// Recording → Transcribing → Sorting → Review → Filed
///         ↘ Discarded    ↘ VoiceNote ↗ (Sort this)
/// ```
sealed class PersonCapturePhase {
  const PersonCapturePhase();
}

/// The recorder is running.
final class PersonCaptureRecording extends PersonCapturePhase {
  const PersonCaptureRecording();
}

/// The recording was thrown away before it was saved.
final class PersonCaptureDiscarded extends PersonCapturePhase {
  const PersonCaptureDiscarded();
}

/// Saved as voice note [audioId]; its words are on their way.
final class PersonCaptureTranscribing extends PersonCapturePhase {
  const PersonCaptureTranscribing(this.audioId);

  final String audioId;
}

/// The words of [audioId] are being sorted.
final class PersonCaptureSorting extends PersonCapturePhase {
  const PersonCaptureSorting(this.audioId, this.transcript);

  final String audioId;
  final String transcript;
}

/// The user reviews what [transcript] sorted into: each item accepted or
/// set aside, and editable, before anything is filed.
final class PersonCaptureReview extends PersonCapturePhase {
  const PersonCaptureReview(this.audioId, this.transcript, this.items);

  final String audioId;
  final String transcript;
  final List<PersonCaptureReviewItem> items;

  /// The items Save files.
  List<PersonCaptureItem> get accepted => [
    for (final item in items)
      if (item.accepted) item.item,
  ];
}

/// One proposed item under review.
final class PersonCaptureReviewItem {
  const PersonCaptureReviewItem(this.item, {this.accepted = true});

  final PersonCaptureItem item;
  final bool accepted;
}

/// Why a capture stayed a voice note.
enum PersonCaptureKept {
  /// Nothing can transcribe it.
  noTranscriber,

  /// It was transcribed into nothing, or the words never came.
  noWords,

  /// Nothing can sort it.
  noSorter,

  /// The sort was asked for and failed.
  sortFailed,

  /// The sort found nothing to file.
  nothingToFile,

  /// The user closed the review.
  closed,
}

/// The capture stays voice note [audioId] — [transcript] its words when it
/// has any — for [reason]. *Sort this* on its row starts sorting again.
final class PersonCaptureVoiceNote extends PersonCapturePhase {
  const PersonCaptureVoiceNote(this.audioId, this.reason, {this.transcript});

  final String audioId;
  final PersonCaptureKept reason;
  final String? transcript;
}

/// The accepted items were filed.
final class PersonCaptureFiled extends PersonCapturePhase {
  const PersonCaptureFiled(this.audioId);

  final String audioId;
}

/// What happens to a capture.
sealed class PersonCaptureEvent {
  const PersonCaptureEvent();
}

/// The recording was saved as [audioId]; [canTranscribe] says whether
/// anything will turn it into words.
final class PersonCaptureSaved extends PersonCaptureEvent {
  const PersonCaptureSaved(this.audioId, {required this.canTranscribe});

  final String audioId;
  final bool canTranscribe;
}

/// The recording was thrown away.
final class PersonCaptureThrownAway extends PersonCaptureEvent {
  const PersonCaptureThrownAway();
}

/// The words arrived, or null when they never will.
final class PersonCaptureHeard extends PersonCaptureEvent {
  const PersonCaptureHeard(this.transcript);

  final String? transcript;
}

/// The sort came back.
final class PersonCaptureSortedAs extends PersonCaptureEvent {
  const PersonCaptureSortedAs(this.sort);

  final PersonCaptureSort sort;
}

/// The user set item [index] aside, or took it back.
final class PersonCaptureToggled extends PersonCaptureEvent {
  const PersonCaptureToggled(this.index);

  final int index;
}

/// The user changed item [index] to [item].
final class PersonCaptureEdited extends PersonCaptureEvent {
  const PersonCaptureEdited(this.index, this.item);

  final int index;
  final PersonCaptureItem item;
}

/// The user closed the review without filing.
final class PersonCaptureClosed extends PersonCaptureEvent {
  const PersonCaptureClosed();
}

/// Items were filed; [remaining] are the accepted ones that could not be,
/// which stay in review so nothing the user accepted is silently lost.
final class PersonCaptureFiledItems extends PersonCaptureEvent {
  const PersonCaptureFiledItems({this.remaining = const []});

  final List<PersonCaptureItem> remaining;
}

/// *Sort this*: voice note [audioId], whose words are [transcript], is
/// sorted again.
final class PersonCaptureSortAgain extends PersonCaptureEvent {
  const PersonCaptureSortAgain(this.audioId, this.transcript);

  final String audioId;
  final String transcript;
}

/// The phase [event] moves [phase] to. An event that does not apply to a
/// phase leaves it where it is: a late transcript for a discarded capture,
/// or a toggle once filed, changes nothing.
PersonCapturePhase personCaptureNext(
  PersonCapturePhase phase,
  PersonCaptureEvent event,
) {
  switch ((phase, event)) {
    case (PersonCaptureRecording(), PersonCaptureThrownAway()):
      return const PersonCaptureDiscarded();
    case (
      PersonCaptureRecording(),
      PersonCaptureSaved(:final audioId, :final canTranscribe),
    ):
      return canTranscribe
          ? PersonCaptureTranscribing(audioId)
          : PersonCaptureVoiceNote(audioId, PersonCaptureKept.noTranscriber);
    case (
      PersonCaptureTranscribing(:final audioId),
      PersonCaptureHeard(:final transcript),
    ):
      final words = transcript?.trim() ?? '';
      return words.isEmpty
          ? PersonCaptureVoiceNote(audioId, PersonCaptureKept.noWords)
          : PersonCaptureSorting(audioId, words);
    case (
      PersonCaptureSorting(:final audioId, :final transcript),
      PersonCaptureSortedAs(:final sort),
    ):
      PersonCaptureVoiceNote kept(PersonCaptureKept reason) =>
          PersonCaptureVoiceNote(audioId, reason, transcript: transcript);
      return switch (sort.outcome) {
        PersonCaptureSortOutcome.noModel => kept(PersonCaptureKept.noSorter),
        PersonCaptureSortOutcome.failed => kept(PersonCaptureKept.sortFailed),
        PersonCaptureSortOutcome.sorted when sort.items.isEmpty => kept(
          PersonCaptureKept.nothingToFile,
        ),
        PersonCaptureSortOutcome.sorted => PersonCaptureReview(
          audioId,
          transcript,
          [for (final item in sort.items) PersonCaptureReviewItem(item)],
        ),
      };
    case (final PersonCaptureReview review, PersonCaptureToggled(:final index))
        when index >= 0 && index < review.items.length:
      final item = review.items[index];
      return PersonCaptureReview(review.audioId, review.transcript, [
        ...review.items.take(index),
        PersonCaptureReviewItem(item.item, accepted: !item.accepted),
        ...review.items.skip(index + 1),
      ]);
    case (
          final PersonCaptureReview review,
          PersonCaptureEdited(:final index, :final item),
        )
        when index >= 0 && index < review.items.length:
      return PersonCaptureReview(review.audioId, review.transcript, [
        ...review.items.take(index),
        PersonCaptureReviewItem(item, accepted: review.items[index].accepted),
        ...review.items.skip(index + 1),
      ]);
    case (final PersonCaptureReview review, PersonCaptureClosed()):
      return PersonCaptureVoiceNote(
        review.audioId,
        PersonCaptureKept.closed,
        transcript: review.transcript,
      );
    case (
      final PersonCaptureReview review,
      PersonCaptureFiledItems(:final remaining),
    ):
      return remaining.isEmpty
          ? PersonCaptureFiled(review.audioId)
          : PersonCaptureReview(review.audioId, review.transcript, [
              for (final item in remaining) PersonCaptureReviewItem(item),
            ]);
    case (
      PersonCaptureVoiceNote(),
      PersonCaptureSortAgain(:final audioId, :final transcript),
    ):
      final words = transcript.trim();
      return words.isEmpty ? phase : PersonCaptureSorting(audioId, words);
    default:
      return phase;
  }
}
