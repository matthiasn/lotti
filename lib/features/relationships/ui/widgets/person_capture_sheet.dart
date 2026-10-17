import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/task_agent_model_identity.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_capture.dart';
import 'package:lotti/features/relationships/model/person_capture_flow.dart';
import 'package:lotti/features/relationships/model/person_name.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/service/person_capture_sorter.dart';
import 'package:lotti/features/relationships/state/person_capture_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/relationships/ui/widgets/person_capture_review.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

/// Opens *Speak about Pip* (plan 2026-10-15, *Speak your mind*): the
/// recorder, then — once the recording is saved as a voice note on the
/// person's timeline — its words, then what they sort into, for the user to
/// review and file.
///
/// With [sortAgain] it opens on a voice note already recorded — *Sort this*
/// on its timeline row — and goes straight to sorting its words.
Future<void> showPersonCaptureSheet({
  required BuildContext context,
  required RelationshipEntry person,
  ({String audioId, String transcript})? sortAgain,
}) async {
  final recorder = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(audioRecorderControllerProvider.notifier);
  try {
    await DsActionModal.show<void>(
      context: context,
      title: context.messages.relationshipCaptureTitle(person.shortName),
      builder: (sheetContext) =>
          PersonCaptureFlowView(person: person, sortAgain: sortAgain),
    );
  } finally {
    // The recorder hides the floating indicator while it is up; a sheet
    // gone mid-take must hand it back, for the take to be stopped there.
    if (sortAgain == null) recorder.setModalVisible(modalVisible: false);
  }
}

/// The sheet's body: one capture, from the recorder to the filing, driven
/// by [personCaptureNext].
class PersonCaptureFlowView extends ConsumerStatefulWidget {
  const PersonCaptureFlowView({
    required this.person,
    this.sortAgain,
    super.key,
  });

  final RelationshipEntry person;
  final ({String audioId, String transcript})? sortAgain;

  @override
  ConsumerState<PersonCaptureFlowView> createState() =>
      _PersonCaptureFlowViewState();
}

class _PersonCaptureFlowViewState extends ConsumerState<PersonCaptureFlowView> {
  late PersonCapturePhase _phase;
  late final Future<PersonCaptureModel?> _model;
  CheckInTranscriptWait? _wait;
  CheckInSpeechFailureKind? _failure;

  /// The recording was saved but could not be put on the timeline: the
  /// capture stops there, rather than sort and file what the person's page
  /// would never show.
  var _notPlaced = false;
  String? _error;
  var _filing = false;

  @override
  void initState() {
    super.initState();
    _model = ref.read(personCaptureSorterProvider).modelFor(widget.person);
    final again = widget.sortAgain;
    if (again == null) {
      _phase = const PersonCaptureRecording();
    } else {
      _phase = personCaptureNext(
        PersonCaptureVoiceNote(again.audioId, PersonCaptureKept.closed),
        PersonCaptureSortAgain(again.audioId, again.transcript),
      );
      // Each step handles its own failures, so nothing is lost by not
      // awaiting it here.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sort();
      });
    }
  }

  @override
  void dispose() {
    // Leaving stops listening, not the work: a transcript still being
    // written lands on the voice note, where the timeline shows it.
    _wait?.cancel();
    super.dispose();
  }

  void _go(PersonCaptureEvent event) {
    if (!mounted) return;
    setState(() => _phase = personCaptureNext(_phase, event));
    if (_phase case PersonCaptureDiscarded() || PersonCaptureFiled()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onRecorded(String audioId, Duration _) async {
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    final timeline = ref.read(personTimelineRepositoryProvider);
    // From here on the capture is a voice note on the person's timeline,
    // whatever happens to the sheet.
    var placed = false;
    try {
      placed = await timeline.addToTimeline(
        personId: widget.person.meta.id,
        entryId: audioId,
      );
      if (!placed) _log('the voice note could not be put on the timeline');
    } catch (error, stackTrace) {
      _log(error, stackTrace);
    }
    if (!placed) {
      if (!mounted) return;
      setState(() => _notPlaced = true);
      _go(PersonCaptureSaved(audioId, canTranscribe: false));
      return;
    }
    bool canTranscribe;
    try {
      canTranscribe = await transcription.canTranscribe();
    } catch (error, stackTrace) {
      // A probe that fails is a transcriber that is not there: the capture
      // stays the voice note it already is.
      _log(error, stackTrace);
      canTranscribe = false;
    }
    _go(PersonCaptureSaved(audioId, canTranscribe: canTranscribe));
    if (_phase is! PersonCaptureTranscribing) return;
    final wait = _wait = transcription.transcribe(
      audioEntryId: audioId,
      relationshipId: widget.person.meta.id,
    );
    _go(PersonCaptureHeard(await wait.result));
    if (_phase is PersonCaptureSorting) await _sort();
  }

  Future<void> _sort() async {
    final phase = _phase;
    if (phase is! PersonCaptureSorting) return;
    final timeline = ref.read(personTimelineRepositoryProvider);
    final sort = await ref
        .read(personCaptureSorterProvider)
        .sort(
          person: widget.person,
          transcript: phase.transcript,
          now: clock.now(),
        );
    // The one line the sort wrote is the voice note's label on the timeline,
    // whatever the review does next: saved before it opens.
    final summary = sort.summary;
    final modelId = sort.modelId;
    if (summary != null && modelId != null) {
      try {
        await timeline.saveVoiceNoteSummary(
          audioId: phase.audioId,
          summary: summary,
          modelId: modelId,
          categoryId: widget.person.meta.categoryId,
        );
      } catch (error, stackTrace) {
        _log(error, stackTrace);
      }
    }
    _go(PersonCaptureSortedAs(sort));
  }

  Future<void> _file(PersonCaptureReview review) async {
    final failed = context.messages.relationshipCaptureFileFailed;
    setState(() {
      _filing = true;
      _error = null;
    });
    List<PersonCaptureItem> remaining;
    try {
      remaining = await ref
          .read(personCaptureFilerProvider)
          .file(
            person: widget.person,
            audioId: review.audioId,
            items: review.accepted,
            now: clock.now(),
          );
    } catch (error, stackTrace) {
      // Whatever went wrong, the sheet leaves its filing state: nothing is
      // known to be filed, so everything stays in review.
      _log(error, stackTrace);
      remaining = review.accepted;
    }
    if (!mounted) return;
    setState(() {
      _filing = false;
      if (remaining.isNotEmpty) _error = failed;
    });
    _go(PersonCaptureFiledItems(remaining: remaining));
  }

  void _log(Object error, [StackTrace? stackTrace]) => ref
      .read(domainLoggerProvider)
      .error(
        LogDomain.general,
        error,
        stackTrace: stackTrace,
        subDomain: 'PersonCaptureSheet',
        message: 'a step of a person capture failed',
      );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final failure = _failure;
    final body = switch (_phase) {
      _ when _notPlaced => _Ending(
        text: messages.relationshipCaptureNotPlaced(widget.person.shortName),
      ),
      _ when failure != null => _Ending(
        text: checkInRecordingFailureCopy(messages, failure).$2,
        title: checkInRecordingFailureCopy(messages, failure).$1,
      ),
      PersonCaptureRecording() => _Recording(
        person: widget.person,
        model: _model,
        onRecorded: _onRecorded,
        onDiscarded: () => _go(const PersonCaptureThrownAway()),
        onFailed: (kind) => setState(() => _failure = kind),
      ),
      PersonCaptureTranscribing() => _Working(
        key: const ValueKey('person-capture-listening'),
        text: messages.relationshipCaptureListening,
      ),
      PersonCaptureSorting() => _Working(
        key: const ValueKey('person-capture-sorting'),
        text: messages.relationshipCaptureSorting,
      ),
      final PersonCaptureReview review => PersonCaptureReviewView(
        review: review,
        now: clock.now(),
        enabled: !_filing,
        error: _error,
        onToggle: (index) => _go(PersonCaptureToggled(index)),
        onEdit: (index, item) => _go(PersonCaptureEdited(index, item)),
      ),
      PersonCaptureVoiceNote(:final reason) => _Ending(
        text: _keptCopy(context, reason),
      ),
      // Both close the sheet as they arrive.
      PersonCaptureDiscarded() || PersonCaptureFiled() => const SizedBox(),
    };
    final review = _phase is PersonCaptureReview
        ? _phase as PersonCaptureReview
        : null;
    final actions = switch (_phase) {
      PersonCaptureRecording() when failure == null => null,
      _ when review != null => DesignSystemModalActionBar(
        primary: DesignSystemButton(
          key: const ValueKey('person-capture-file'),
          label: messages.relationshipCaptureFile(review.accepted.length),
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: _filing || review.accepted.isEmpty
              ? null
              : () => _file(review),
        ),
        secondary: [
          DesignSystemButton(
            key: const ValueKey('person-capture-keep'),
            label: messages.relationshipCaptureKeepVoiceNote,
            variant: DesignSystemButtonVariant.quiet,
            onPressed: _filing
                ? null
                : () {
                    _go(const PersonCaptureClosed());
                    Navigator.of(context).pop();
                  },
          ),
        ],
      ),
      _ => DesignSystemModalActionBar(
        primary: DesignSystemButton(
          key: const ValueKey('person-capture-done'),
          label: messages.doneButton,
          size: DesignSystemButtonSize.large,
          fullWidth: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    };
    // Recording, the recorder's own Stop and Discard are the ways out; a
    // filing in flight holds the sheet until it lands.
    return PopScope(
      canPop:
          !(_phase is PersonCaptureRecording && failure == null) && !_filing,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          body,
          if (actions != null) ...[
            SizedBox(height: tokens.spacing.step5),
            actions,
          ],
        ],
      ),
    );
  }

  String _keptCopy(BuildContext context, PersonCaptureKept reason) {
    final messages = context.messages;
    return switch (reason) {
      PersonCaptureKept.noTranscriber =>
        messages.relationshipCaptureKeptNoTranscriber,
      PersonCaptureKept.noWords => messages.relationshipCaptureKeptNoWords,
      PersonCaptureKept.noSorter => messages.relationshipCaptureKeptNoSorter,
      PersonCaptureKept.sortFailed =>
        messages.relationshipCaptureKeptSortFailed,
      PersonCaptureKept.nothingToFile ||
      PersonCaptureKept.closed => messages.relationshipCaptureKeptNothingToFile,
    };
  }
}

/// The recorder, under what a capture can be and over where it will be
/// sorted — named before anything is sent, as the briefing names its model
/// before *Brief now*.
class _Recording extends StatelessWidget {
  const _Recording({
    required this.person,
    required this.model,
    required this.onRecorded,
    required this.onDiscarded,
    required this.onFailed,
  });

  final RelationshipEntry person;
  final Future<PersonCaptureModel?> model;
  final void Function(String audioEntryId, Duration length) onRecorded;
  final VoidCallback onDiscarded;
  final void Function(CheckInSpeechFailureKind failure) onFailed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final quiet = tokens.colors.text.mediumEmphasis;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          messages.relationshipCaptureHint,
          key: const ValueKey('person-capture-hint'),
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: quiet,
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        CheckInInlineRecorder(
          linkedId: person.meta.id,
          categoryId: person.meta.categoryId,
          onRecorded: onRecorded,
          onDiscarded: onDiscarded,
          onFailed: onFailed,
        ),
        SizedBox(height: tokens.spacing.step4),
        FutureBuilder<PersonCaptureModel?>(
          future: model,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox.shrink();
            }
            final model = snapshot.data;
            return Text(
              model == null
                  ? messages.relationshipCaptureNoSorter
                  : messages.relationshipCaptureSortedBy(
                      inferenceRouteIdentityTiers(
                        model.route,
                        viaLabel: messages.taskAgentRouteVia,
                        alwaysNameProvider: true,
                      ).first,
                    ),
              key: const ValueKey('person-capture-route'),
              textAlign: TextAlign.center,
              style: tokens.typography.styles.others.caption.copyWith(
                color: quiet,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Work under way: a spinner beside what it is.
class _Working extends StatelessWidget {
  const _Working({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const DesignSystemSpinner(),
          SizedBox(width: tokens.spacing.step3),
          Flexible(
            child: Text(
              text,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How a capture ended short of filing: in one plain sentence, under a
/// title when there is one.
class _Ending extends StatelessWidget {
  const _Ending({required this.text, this.title});

  final String text;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      key: const ValueKey('person-capture-ending'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title case final title?) ...[
          Text(
            title,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
        ],
        Text(
          text,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
