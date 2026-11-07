import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/chat_recording_pill.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the stage's controls.
abstract final class FrontStageControlKeys {
  static const Key talk = Key('front-stage-talk');
  static const Key caption = Key('front-stage-talk-caption');
}

/// What stands at her feet on her stage: a way to answer her, and her
/// latest answer said again — so the stage is never only a figure to look
/// at, whatever has been said so far.
///
/// One disc is the stage's one control to talk with, in every state. Held,
/// she listens, and letting go sends what was said; dragged off before
/// letting go, it turns to a red ×, and letting go lets it go unsent. A
/// quick tap — and a screen reader's tap, Space or Enter — starts her
/// listening hands free, and the disc, now the send arrow, sends on the
/// next tap. While she listens, the chats' own recording pill
/// ([ChatRecordingPill], without its own send) shows the time and the voice
/// above the disc, × letting it go; while the words are written down and
/// while she answers, the disc waits. The band keeps its height in every
/// state, so nothing moves under a finger.
///
/// What was said reaches her as the conversation's spoken turn: the
/// conversation's composer, which the stage only covers, sends the
/// transcript the shared recorder hands it, as it does any other — her
/// answer is then spoken here. Her ears are the same: the Settings
/// default's transcription slot.
class FrontStageControls extends ConsumerStatefulWidget {
  const FrontStageControls({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<FrontStageControls> createState() => _FrontStageControlsState();
}

class _FrontStageControlsState extends ConsumerState<FrontStageControls> {
  Timer? _holdTimer;

  /// The disc is pressed.
  bool _pressing = false;

  /// The press started her listening: a hold, or a tap that leaves her
  /// listening hands free.
  bool _fromIdle = false;

  /// Pressed long enough, while she listens, to be a hold: letting go sends.
  bool _held = false;

  /// Dragged off the disc: letting go sends nothing.
  bool _off = false;

  /// The disc's square with the room a finger may stray before it counts as
  /// gone — set by the build, read by the pointer handlers.
  Rect _bounds = Rect.zero;

  ChatRecorderController get _recorder =>
      ref.read(chatRecorderControllerProvider.notifier);

  ChatRecorderStatus get _status =>
      ref.read(chatRecorderControllerProvider).status;

  /// Her answer is on its way: nothing to say to her until it lands.
  bool _waitingOnHer() =>
      ref.read(frontChatControllerProvider).isSending ||
      ref.read(frontSpokenTurnProvider) != null;

  void _start() => _recorder
      .start(
        resolveTranscriptionTarget: ref.read(
          settingsDefaultDictationTargetProvider,
        ),
      )
      .ignore();

  void _send() => _recorder.stopAndTranscribe().ignore();

  /// A tap that is not a press: a screen reader's, Space, Enter.
  void _tap() {
    switch (_status) {
      case ChatRecorderStatus.idle when !_waitingOnHer():
        _start();
      case ChatRecorderStatus.recording:
        _send();
      case _:
        break;
    }
  }

  void _down(PointerDownEvent event) {
    final status = _status;
    if (status == ChatRecorderStatus.processing ||
        (status == ChatRecorderStatus.idle && _waitingOnHer())) {
      return;
    }
    final fromIdle = status == ChatRecorderStatus.idle;
    setState(() {
      _pressing = true;
      _fromIdle = fromIdle;
      _off = false;
    });
    if (!fromIdle) return;
    HapticFeedback.selectionClick().ignore();
    _start();
    _holdTimer = Timer(kLongPressTimeout, () {
      // Only a hold she is listening to: a microphone refused never
      // promises a send.
      if (!mounted || !_pressing || _status != ChatRecorderStatus.recording) {
        return;
      }
      HapticFeedback.mediumImpact().ignore();
      setState(() => _held = true);
    });
  }

  void _move(PointerMoveEvent event) {
    if (!_pressing) return;
    final off = !_bounds.contains(event.localPosition);
    if (off != _off) setState(() => _off = off);
  }

  void _up(PointerUpEvent _) {
    final (fromIdle, held, off) = (_fromIdle, _held, _off);
    _release();
    if (off) {
      // Let go off the disc: what the press started goes unsent; hands
      // free, a tap that slid off is no tap.
      if (fromIdle) _recorder.cancel().ignore();
      return;
    }
    // A hold sends; hands free, the tap on the arrow sends; a tap that
    // started her leaves her listening.
    if (held || !fromIdle) _send();
  }

  /// The press was taken away — a scroll, a system gesture: what a press
  /// started goes unsent; hands free, she listens on.
  void _cancel(PointerCancelEvent _) {
    final fromIdle = _fromIdle;
    _release();
    if (fromIdle && _status == ChatRecorderStatus.recording) {
      _recorder.cancel().ignore();
    }
  }

  void _release() {
    _holdTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _pressing = false;
      _fromIdle = false;
      _held = false;
      _off = false;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final recorder = ref.watch(chatRecorderControllerProvider);
    final listening = recorder.status == ChatRecorderStatus.recording;
    final transcribing = recorder.status == ChatRecorderStatus.processing;
    final thinking =
        recorder.status == ChatRecorderStatus.idle &&
        (ref.watch(frontChatControllerProvider.select((s) => s.isSending)) ||
            ref.watch(frontSpokenTurnProvider) != null);
    final waiting = transcribing || thinking;
    final cancelling = _off && _fromIdle;
    // Held, or hands free: what letting go, or the next tap, does.
    final sends = listening && (_held || !_fromIdle) && !cancelling;
    final disc = tokens.spacing.step10;
    _bounds = (Offset.zero & Size.square(disc)).inflate(tokens.spacing.step6);

    final caption = switch (()) {
      _ when transcribing => messages.timelineTranscribing,
      _ when thinking => messages.frontChatResponding,
      _ when cancelling => messages.frontStageReleaseToCancel,
      _ when listening && _held => messages.frontStageReleaseToSend,
      _ when listening && !_fromIdle => messages.frontStageTapToSend,
      _ => messages.frontStageHoldToTalk,
    };
    final fill = switch (()) {
      _ when waiting => tokens.colors.surface.enabled,
      _ when cancelling => tokens.colors.alert.error.defaultColor,
      _ when _pressing => tokens.colors.interactive.pressed,
      _ => tokens.colors.interactive.enabled,
    };
    final glyph = waiting
        ? DesignSystemSpinner(
            style: DesignSystemSpinnerStyle.plain,
            size: IconSizes.m,
            color: tokens.colors.text.mediumEmphasis,
          )
        : Icon(
            cancelling
                ? LottiIcons.close
                : sends
                ? LottiIcons.arrowUp
                : LottiIcons.mic,
            size: IconSizes.l,
            color: tokens.colors.text.onInteractiveAlert,
          );

    final talk = Semantics(
      button: true,
      enabled: !waiting,
      label: caption,
      onTap: waiting ? null : _tap,
      child: ExcludeSemantics(
        child: Focus(
          onKeyEvent: (node, event) {
            final key = event.logicalKey;
            if (event is! KeyDownEvent ||
                (key != LogicalKeyboardKey.space &&
                    key != LogicalKeyboardKey.enter)) {
              return KeyEventResult.ignored;
            }
            _tap();
            return KeyEventResult.handled;
          },
          child: Listener(
            key: FrontStageControlKeys.talk,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _cancel,
            child: DecoratedBox(
              decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              child: SizedBox.square(
                dimension: disc,
                child: Center(child: glyph),
              ),
            ),
          ),
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kActionListContentMaxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The pill's place, kept when it is not there: nothing moves as
          // she starts and stops listening.
          SizedBox(
            height: tokens.spacing.step9,
            child: listening || transcribing
                ? ChatRecordingPill(
                    processing: transcribing,
                    amplitudes: _recorder.getNormalizedAmplitudeHistory(),
                    elapsed: recorder.elapsed,
                    // The disc sends: one send on screen.
                    showEndControl: false,
                    onCancel: () {
                      _release();
                      _recorder.cancel().ignore();
                    },
                    onStop: _send,
                  )
                : null,
          ),
          SizedBox(height: tokens.spacing.step6),
          // The disc centred, her answer said again beside it.
          Row(
            children: [
              const Spacer(),
              talk,
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: tokens.spacing.step5,
                    ),
                    child: listening || waiting
                        ? null
                        : FrontVoiceButton(
                            conversationId: widget.conversationId,
                          ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step3),
          // The disc says it; a reader hears it once.
          ExcludeSemantics(
            child: Text(
              caption,
              key: FrontStageControlKeys.caption,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: cancelling
                    ? tokens.colors.alert.error.ink
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
