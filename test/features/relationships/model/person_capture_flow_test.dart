import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/model/person_capture_flow.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';

void main() {
  const note = PersonCaptureNote(text: 'Collects sextants.');
  const task = PersonCaptureTask(title: 'Send the draft');
  const checkIn = PersonCaptureCheckIn(
    interactionType: CheckInInteractionType.call,
    summary: 'Talked about the launch.',
  );
  const sorting = PersonCaptureSorting('audio-1', 'Words.');
  const review = PersonCaptureReview('audio-1', 'Words.', [
    PersonCaptureReviewItem(checkIn),
    PersonCaptureReviewItem(note),
  ]);

  String describe(PersonCapturePhase phase) => switch (phase) {
    PersonCaptureRecording() => 'recording',
    PersonCaptureDiscarded() => 'discarded',
    PersonCaptureTranscribing(:final audioId) => 'transcribing $audioId',
    PersonCaptureSorting(:final audioId, :final transcript) =>
      'sorting $audioId "$transcript"',
    PersonCaptureReview(:final items) =>
      'review ${items.map((item) => item.accepted ? '+' : '-').join()}',
    PersonCaptureVoiceNote(:final reason, :final transcript) =>
      'voice note ${reason.name}${transcript == null ? '' : ' "$transcript"'}',
    PersonCaptureFiled(:final audioId) => 'filed $audioId',
  };

  PersonCaptureSort sort(
    PersonCaptureSortOutcome outcome, [
    List<PersonCaptureItem> items = const [],
  ]) => (outcome: outcome, items: items);

  final table = <(String, PersonCapturePhase, PersonCaptureEvent, String)>[
    (
      'a saved recording with a transcriber waits for its words',
      const PersonCaptureRecording(),
      const PersonCaptureSaved('audio-1', canTranscribe: true),
      'transcribing audio-1',
    ),
    (
      'a saved recording with no transcriber stays a voice note',
      const PersonCaptureRecording(),
      const PersonCaptureSaved('audio-1', canTranscribe: false),
      'voice note noTranscriber',
    ),
    (
      'a recording thrown away is gone',
      const PersonCaptureRecording(),
      const PersonCaptureThrownAway(),
      'discarded',
    ),
    (
      'words arrive, trimmed, and are sorted',
      const PersonCaptureTranscribing('audio-1'),
      const PersonCaptureHeard('  Words.  '),
      'sorting audio-1 "Words."',
    ),
    (
      'no words, or blank ones, keep the voice note',
      const PersonCaptureTranscribing('audio-1'),
      const PersonCaptureHeard('   '),
      'voice note noWords',
    ),
    (
      'a transcript that never came keeps the voice note',
      const PersonCaptureTranscribing('audio-1'),
      const PersonCaptureHeard(null),
      'voice note noWords',
    ),
    (
      'a sort with items opens the review, every item accepted',
      sorting,
      PersonCaptureSortedAs(
        sort(PersonCaptureSortOutcome.sorted, const [checkIn, note]),
      ),
      'review ++',
    ),
    (
      'a sort with nothing to file keeps the voice note and its words',
      sorting,
      PersonCaptureSortedAs(sort(PersonCaptureSortOutcome.sorted)),
      'voice note nothingToFile "Words."',
    ),
    (
      'no sorter keeps the voice note',
      sorting,
      PersonCaptureSortedAs(sort(PersonCaptureSortOutcome.noModel)),
      'voice note noSorter "Words."',
    ),
    (
      'a failed sort keeps the voice note',
      sorting,
      PersonCaptureSortedAs(sort(PersonCaptureSortOutcome.failed)),
      'voice note sortFailed "Words."',
    ),
    (
      'an item is set aside',
      review,
      const PersonCaptureToggled(1),
      'review +-',
    ),
    (
      'a toggle out of range changes nothing',
      review,
      const PersonCaptureToggled(5),
      'review ++',
    ),
    (
      'closing the review keeps the voice note',
      review,
      const PersonCaptureClosed(),
      'voice note closed "Words."',
    ),
    (
      'everything filed is filed',
      review,
      const PersonCaptureFiledItems(),
      'filed audio-1',
    ),
    (
      'what could not be filed stays in review, accepted',
      review,
      const PersonCaptureFiledItems(remaining: [note]),
      'review +',
    ),
    (
      'Sort this sorts a voice note again',
      const PersonCaptureVoiceNote('audio-1', PersonCaptureKept.closed),
      const PersonCaptureSortAgain('audio-1', ' Words. '),
      'sorting audio-1 "Words."',
    ),
    (
      'Sort this on a voice note without words does nothing',
      const PersonCaptureVoiceNote('audio-1', PersonCaptureKept.noWords),
      const PersonCaptureSortAgain('audio-1', '  '),
      'voice note noWords',
    ),
    (
      'a late transcript for a discarded capture changes nothing',
      const PersonCaptureDiscarded(),
      const PersonCaptureHeard('Words.'),
      'discarded',
    ),
    (
      'a toggle once filed changes nothing',
      const PersonCaptureFiled('audio-1'),
      const PersonCaptureToggled(0),
      'filed audio-1',
    ),
  ];

  for (final (name, from, event, to) in table) {
    test(name, () => expect(describe(personCaptureNext(from, event)), to));
  }

  test('an edit replaces its item and keeps whether it was accepted', () {
    final setAside = personCaptureNext(review, const PersonCaptureToggled(1));
    final edited =
        personCaptureNext(setAside, const PersonCaptureEdited(1, task))
            as PersonCaptureReview;

    expect(edited.items[1].item, task);
    expect(edited.items[1].accepted, isFalse);
    expect(edited.items[0].item, checkIn);
    expect(edited.accepted, [checkIn]);
    expect(
      personCaptureNext(review, const PersonCaptureEdited(-1, task)),
      same(review),
    );
  });
}
