import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The idle composer field every chat-shaped input shares: one text field
/// whose trailing icon is the mic while it is empty and the send arrow once
/// there are words.
///
/// It owns no recording: [onStartRecording] says what the mic does, so a
/// host can record however it records — the agent chat through its shared
/// recorder, Daily OS through its own capture flow — while the field looks
/// and behaves the same everywhere.
///
/// [isSending] disables the field (unless [allowDraftWhileSending]) and
/// shows [sendingLabel] under it; Enter sends when there is something to
/// send. [enabled] false closes the field outright — no typing, no mic, no
/// send — for a host that cannot take a message yet.
class ChatComposerField extends StatelessWidget {
  const ChatComposerField({
    required this.controller,
    required this.hintText,
    required this.draft,
    required this.onDraftChanged,
    required this.onSend,
    required this.onStartRecording,
    this.isSending = false,
    this.allowDraftWhileSending = false,
    this.sendingLabel,
    this.shape = DesignSystemTextInputShape.pill,
    this.autofocus = false,
    this.enabled = true,
    super.key,
  });

  final bool autofocus;
  final bool enabled;
  final TextEditingController controller;
  final String hintText;
  final bool isSending;
  final bool allowDraftWhileSending;
  final String? sendingLabel;
  final String draft;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onSend;
  final VoidCallback onStartRecording;
  final DesignSystemTextInputShape shape;

  @override
  Widget build(BuildContext context) {
    final hasText = draft.trim().isNotEmpty;
    final canSend = enabled && hasText && !isSending;
    final canRecord = enabled && !isSending && !hasText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: DesignSystemTextInput(
            controller: controller,
            autofocus: autofocus,
            shape: shape,
            hintText: hintText,
            helperText: isSending && !allowDraftWhileSending
                ? sendingLabel
                : null,
            enabled: enabled && (!isSending || allowDraftWhileSending),
            textCapitalization: TextCapitalization.sentences,
            emphasizeTrailingIcon:
                hasText && shape == DesignSystemTextInputShape.pill,
            trailingIcon: hasText
                ? (shape == DesignSystemTextInputShape.pill
                      ? LottiIcons.arrowUp
                      : LottiIcons.send)
                : (canRecord ? LottiIcons.mic : null),
            onTrailingIconTap: hasText
                ? (canSend ? onSend : null)
                : (canRecord ? onStartRecording : null),
            trailingIconTooltip: hasText
                ? context.messages.chatInputSendTooltip
                : (canRecord ? context.messages.chatInputRecordVoice : null),
            onChanged: onDraftChanged,
            onSubmitted: (_) {
              if (canSend) onSend();
            },
          ),
        ),
      ],
    );
  }
}
