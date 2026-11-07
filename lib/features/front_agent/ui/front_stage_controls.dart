import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/agents/ui/chat/chat_recording_pill.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
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
/// The talk disc is held to talk: pressing starts listening, and letting go
/// after a hold sends what was said. A quick tap starts listening too and
/// leaves it running, hands free, until the pill's send arrow (or × and
/// Escape, which let it go) — the way a screen reader, which taps, talks
/// to her. While she listens or writes it down, the chats' own recording
/// pill ([ChatRecordingPill]) stands over the disc.
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

  /// The disc is pressed: it stays, under the finger, whatever the
  /// recorder does.
  bool _pressing = false;

  /// Pressed long enough to be a hold: letting go sends.
  bool _held = false;

  ChatRecorderController get _recorder =>
      ref.read(chatRecorderControllerProvider.notifier);

  void _start() => _recorder
      .start(
        resolveTranscriptionTarget: ref.read(
          settingsDefaultDictationTargetProvider,
        ),
      )
      .ignore();

  void _down(PointerDownEvent _) {
    if (ref.read(chatRecorderControllerProvider).status !=
        ChatRecorderStatus.idle) {
      return;
    }
    setState(() => _pressing = true);
    _start();
    _holdTimer = Timer(kLongPressTimeout, () {
      if (mounted) setState(() => _held = true);
    });
  }

  void _up(PointerUpEvent _) {
    final held = _held;
    _release();
    if (held) _recorder.stopAndTranscribe().ignore();
  }

  /// The press was taken away — a scroll, a system gesture: a hold is let
  /// go unsent; a tap's listening carries on.
  void _cancel(PointerCancelEvent _) {
    final held = _held;
    _release();
    if (held) _recorder.cancel().ignore();
  }

  void _release() {
    _holdTimer?.cancel();
    if (!_pressing && !_held) return;
    setState(() {
      _pressing = false;
      _held = false;
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
    final live =
        recorder.status == ChatRecorderStatus.recording ||
        recorder.status == ChatRecorderStatus.processing;
    // Under a finger it stays; hands free, the pill alone carries on.
    final showDisc = !live || _pressing;
    final disc = tokens.spacing.step10;

    final talk = Semantics(
      button: true,
      label: messages.frontStageHoldToTalk,
      // A screen reader taps: listening starts hands free.
      onTap: live ? null : _start,
      child: ExcludeSemantics(
        child: Listener(
          key: FrontStageControlKeys.talk,
          onPointerDown: _down,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: Material(
            color: tokens.colors.interactive.enabled,
            shape: const CircleBorder(),
            child: SizedBox.square(
              dimension: disc,
              // Held, it shows what letting go does.
              child: Icon(
                _held ? LottiIcons.arrowUp : LottiIcons.mic,
                size: IconSizes.l,
                color: tokens.colors.text.onInteractiveAlert,
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
          if (live)
            ChatRecordingPill(
              processing: recorder.status == ChatRecorderStatus.processing,
              amplitudes: _recorder.getNormalizedAmplitudeHistory(),
              elapsed: recorder.elapsed,
              sendsOnStop: true,
              onCancel: () => _recorder.cancel().ignore(),
              onStop: () => _recorder.stopAndTranscribe().ignore(),
            ),
          if (live && showDisc) SizedBox(height: tokens.spacing.step5),
          if (showDisc) ...[
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
                      child: live
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
                _held
                    ? messages.frontStageReleaseToSend
                    : messages.frontStageHoldToTalk,
                key: FrontStageControlKeys.caption,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
