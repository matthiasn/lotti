import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_error_message.dart';
import 'package:lotti/features/agents/ui/chat/waveform_bars.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/textareas/design_system_textarea.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/state/goal_agent_providers.dart';
import 'package:lotti/features/goals/state/goal_dictation_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the sheet for one charter entry of the goal coached by [agentId]
/// (ADR 0140): a new one, or [entry] to edit — a note's words, or a
/// recording's transcript.
///
/// The charter is what the user tells the agent the goal is FOR — written
/// here, never in the chat. Voice in this sheet is dictation into the field,
/// so what the agent reads word for word is what the user saw and could
/// correct; a recording the user wants to keep is made from the card instead
/// (`recordGoalCharterEntry`) and corrected here through its transcript.
Future<void> showGoalCharterSheet({
  required BuildContext context,
  required String agentId,
  JournalEntity? entry,
}) => DsActionModal.show<void>(
  context: context,
  title: context.messages.goalCharterTitle,
  builder: (sheetContext) => GoalCharterForm(agentId: agentId, entry: entry),
);

/// The charter sheet's body: the words, dictation, and the sheet's actions.
class GoalCharterForm extends ConsumerStatefulWidget {
  const GoalCharterForm({required this.agentId, this.entry, super.key});

  final String agentId;

  /// The entry being edited — a note, or a recording whose transcript is
  /// edited; null for a new note.
  final JournalEntity? entry;

  @override
  ConsumerState<GoalCharterForm> createState() => _GoalCharterFormState();
}

class _GoalCharterFormState extends ConsumerState<GoalCharterForm> {
  late final TextEditingController _text = TextEditingController(
    text: widget.entry?.entryText?.plainText ?? '',
  );
  var _saving = false;

  /// What went wrong with the last save, delete or dictation, said under the
  /// field — a toast raised from here would render behind the sheet.
  String? _error;

  /// The shared voice recorder. Read once, here, so [dispose] can still
  /// reach it; the sheet watches the provider, which keeps it alive.
  late final ChatRecorderController _recorder;

  /// Whether the recorder's current take is one this sheet started.
  ///
  /// The recorder is shared — the goal's chat composer uses the same one —
  /// so a take someone else started must neither land in the charter nor be
  /// shown or stopped here, and closing the sheet cancels only its own.
  var _ownsRecording = false;

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(chatRecorderControllerProvider.notifier);
    _text.addListener(_changed);
    ref.listenManual<ChatRecorderState>(chatRecorderControllerProvider, (
      previous,
      next,
    ) {
      if (!_ownsRecording) return;
      if (next.error != null && next.error != previous?.error) {
        setState(() {
          _error = chatRecorderErrorMessage(context, next.errorKind);
          _ownsRecording = false;
        });
        Future.microtask(_recorder.clearResult);
        return;
      }
      final transcript = next.transcript?.trim();
      if (transcript != null &&
          transcript.isNotEmpty &&
          next.transcript != previous?.transcript) {
        _append(transcript);
        setState(() => _ownsRecording = false);
        Future.microtask(_recorder.clearResult);
        return;
      }
      // Back to idle with nothing to show: cancelled, or silence.
      if (next.status == ChatRecorderStatus.idle &&
          previous?.status != ChatRecorderStatus.idle) {
        setState(() => _ownsRecording = false);
      }
    });
  }

  @override
  void dispose() {
    // A take this sheet started must not outlive it and land elsewhere.
    // Deferred, because a provider may not change while the tree is being
    // torn down; when the sheet was its only listener the provider disposes
    // first, which ends the take itself, and `cancel` returns unmounted.
    // Ownership drops first, so the idle the cancel publishes reaches a
    // listener that ignores it rather than one that rebuilds a dead sheet.
    if (_ownsRecording) {
      _ownsRecording = false;
      Future.microtask(_recorder.cancel);
    }
    _text
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _startDictation() {
    setState(() {
      _ownsRecording = true;
      _error = null;
    });
    final dictation = ref.read(goalDictationProvider(widget.agentId));
    _recorder.start(
      resolveTranscriptionTarget: dictation?.resolveTarget,
      correctTranscript: dictation?.correct,
    );
  }

  void _changed() => setState(() => _error = null);

  /// Dictation adds to what is written; it never replaces it.
  void _append(String transcript) {
    final current = _text.text.trimRight();
    _text
      ..text = current.isEmpty ? transcript : '$current\n\n$transcript'
      ..selection = TextSelection.collapsed(offset: _text.text.length);
  }

  bool get _recorderBusy =>
      _ownsRecording &&
      ref.read(chatRecorderControllerProvider).status !=
          ChatRecorderStatus.idle;

  bool get _canSave =>
      !_saving && !_recorderBusy && _text.text.trim().isNotEmpty;

  /// Saves the entry and closes the sheet; a write that fails, or throws,
  /// keeps the sheet open on the words with the reason under them.
  Future<void> _save() async {
    final failed = context.messages.goalCharterSaveFailed;
    final repository = ref.read(goalRepositoryProvider);
    if (repository == null) {
      setState(() => _error = failed);
      return;
    }
    setState(() => _saving = true);
    final entry = widget.entry;
    final saved = await _attempt(
      () async => entry == null
          ? await repository.createCharterEntry(
                  agentId: widget.agentId,
                  text: _text.text,
                ) !=
                null
          : repository.updateCharterEntry(
              entry,
              agentId: widget.agentId,
              text: _text.text,
            ),
    );
    _settle(saved, error: failed);
  }

  /// Deletes the entry and closes the sheet, or says it could not.
  Future<void> _delete(JournalEntity entry) async {
    final failed = context.messages.journalDeleteFailed;
    final repository = ref.read(goalRepositoryProvider);
    if (repository == null) {
      setState(() => _error = failed);
      return;
    }
    setState(() => _saving = true);
    final deleted = await _attempt(
      () => repository.deleteCharterEntry(entry, agentId: widget.agentId),
    );
    _settle(deleted, error: failed);
  }

  /// Runs a write, reading a throw as the failure it is.
  Future<bool> _attempt(Future<bool> Function() write) async {
    try {
      return await write();
    } catch (error, stackTrace) {
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.general,
            error,
            stackTrace: stackTrace,
            subDomain: 'GoalCharterSheet',
            message: 'Failed to write a goal charter entry',
          );
      return false;
    }
  }

  void _settle(bool done, {required String error}) {
    if (!mounted) return;
    if (done) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final entry = widget.entry;
    // Rebuild on every recorder phase: Save waits for dictation to land.
    final status = ref.watch(
      chatRecorderControllerProvider.select((state) => state.status),
    );
    // Another consumer's take reads as idle here, with Dictate unavailable
    // until the shared recorder is free.
    final shown = _ownsRecording ? status : ChatRecorderStatus.idle;
    void saveIfReady() {
      if (_canSave) _save();
    }

    // ⌘/Ctrl+Enter saves, as in the check-in composer and the note sheet.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            saveIfReady,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            saveIfReady,
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignSystemTextarea(
            key: const ValueKey('goal-charter-text'),
            controller: _text,
            hintText: messages.goalCharterHint,
            errorText: _error,
            minLines: 5,
            growWithContent: true,
            enabled: shown == ChatRecorderStatus.idle,
            semanticsLabel: messages.goalCharterTitle,
          ),
          // A recording's words come from the recording; dictating more into
          // its transcript would put words in its mouth.
          if (entry is! JournalAudio) ...[
            SizedBox(height: tokens.spacing.step3),
            GoalCharterDictation(
              status: shown,
              onStart: status == ChatRecorderStatus.idle
                  ? _startDictation
                  : null,
            ),
          ],
          SizedBox(height: tokens.spacing.step5),
          DesignSystemModalActionBar(
            primary: DesignSystemButton(
              key: const ValueKey('goal-charter-save'),
              label: messages.saveButtonLabel,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              onPressed: _canSave ? _save : null,
            ),
            secondary: [
              if (entry != null)
                DesignSystemButton(
                  key: const ValueKey('goal-charter-delete'),
                  label: messages.deleteButton,
                  variant: DesignSystemButtonVariant.danger,
                  onPressed: _saving ? null : () => _delete(entry),
                ),
              DesignSystemButton(
                key: const ValueKey('goal-charter-cancel'),
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.quiet,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dictation row under the charter field, in the recorder's phase.
///
/// Idle: *Dictate*, ending the row. Recording: the elapsed time in a fixed
/// slot of tabular figures — so the waveform never shifts as digits change —
/// the waveform, then Cancel and Stop. Transcribing: a spinner and its label.
class GoalCharterDictation extends ConsumerWidget {
  const GoalCharterDictation({
    required this.status,
    required this.onStart,
    super.key,
  });

  /// The phase of the sheet's own take — idle while there is none.
  final ChatRecorderStatus status;

  /// Starts a take owned by the sheet; null while the shared recorder is
  /// busy with someone else's.
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final recorder = ref.read(chatRecorderControllerProvider.notifier);
    switch (status) {
      case ChatRecorderStatus.idle:
        return Align(
          alignment: AlignmentDirectional.centerEnd,
          child: DesignSystemButton(
            key: const ValueKey('goal-charter-dictate'),
            label: messages.checkInDictateButton,
            leadingIcon: LottiIcons.mic,
            variant: DesignSystemButtonVariant.quiet,
            alignsLabelToTrailingEdge: true,
            onPressed: onStart,
          ),
        );
      case ChatRecorderStatus.recording:
        final elapsed = ref.watch(
          chatRecorderControllerProvider.select((state) => state.elapsed),
        );
        // Watched so the waveform moves with the voice.
        ref.watch(
          chatRecorderControllerProvider.select(
            (state) => state.amplitudeHistory,
          ),
        );
        return Row(
          key: const ValueKey('goal-charter-recording'),
          children: [
            SizedBox(
              width: tokens.spacing.step9,
              child: Text(
                _elapsedLabel(elapsed),
                key: const ValueKey('goal-charter-elapsed'),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: WaveformBars(
                amplitudesNormalized: recorder.getNormalizedAmplitudeHistory(),
              ),
            ),
            SizedBox(width: tokens.spacing.step3),
            DesignSystemButton(
              key: const ValueKey('goal-charter-dictation-cancel'),
              label: messages.cancelButton,
              variant: DesignSystemButtonVariant.quiet,
              onPressed: recorder.cancel,
            ),
            DesignSystemButton(
              key: const ValueKey('goal-charter-dictation-stop'),
              label: messages.audioRecordingStop,
              leadingIcon: LottiIcons.stop,
              onPressed: recorder.stopAndTranscribe,
            ),
          ],
        );
      case ChatRecorderStatus.processing:
        return Row(
          key: const ValueKey('goal-charter-transcribing'),
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const DesignSystemSpinner(size: IconSizes.s),
            SizedBox(width: tokens.spacing.step2),
            Text(
              messages.timelineTranscribing,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        );
    }
  }
}

String _elapsedLabel(Duration elapsed) {
  final minutes = elapsed.inMinutes.toString().padLeft(2, '0');
  final seconds = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
