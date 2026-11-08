import 'dart:math' as math;

import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemChatInputWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Chat input',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ChatInputStatesPage(),
      ),
    ],
  );
}

/// What the overview shows the input with.
abstract final class DesignSystemChatInputWidgetbook {
  /// A conversation's reading column: the widest the input is shown, so a
  /// desktop frame shows it as a chat does and a phone frame at its width.
  static const double maxWidth = 720;

  /// A take's loudness for the recording state: speech with pauses, long
  /// enough to fill the row.
  static final List<double> sampleLevels = [
    for (var i = 0; i < 400; i++)
      (math.sin(i * 0.31).abs() * math.cos(i * 0.07).abs() * 0.9 + 0.05).clamp(
        0.0,
        1.0,
      ),
  ];
}

class _ChatInputStatesPage extends StatelessWidget {
  const _ChatInputStatesPage();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    void noop() {}
    DesignSystemChatInput input({
      String text = '',
      DesignSystemChatInputPhase phase = DesignSystemChatInputPhase.compose,
      String? partial,
      String? busy,
      String? error,
      List<DesignSystemChatInputMention> mentions = const [],
    }) => DesignSystemChatInput(
      // The caret after the words, where `@` looks for what it completes.
      controller: TextEditingController.fromValue(
        TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        ),
      ),
      hintText: messages.designSystemChatInputHintSample,
      helperText: messages.designSystemChatInputHelperSample,
      phase: phase,
      levels: DesignSystemChatInputWidgetbook.sampleLevels,
      elapsed: const Duration(seconds: 33),
      partialTranscript: partial,
      busyText: busy,
      errorText: error,
      onRetry: error == null ? null : noop,
      mentionOptions: mentions,
      onSend: noop,
      onStartRecording: noop,
      onCancelRecording: noop,
      onFinishRecording: noop,
    );

    final states = <(String, Widget)>[
      (messages.designSystemChatInputIdleLabel, input()),
      (
        messages.designSystemChatInputProofreadLabel,
        input(text: messages.designSystemChatInputDraftSample),
      ),
      (
        messages.designSystemChatInputMentionLabel,
        input(
          text: messages.designSystemChatInputMentionDraftSample,
          mentions: [
            DesignSystemChatInputMention(
              label: messages.designSystemChatInputMentionWork,
              color: tokens.colors.alert.info.defaultColor,
            ),
            DesignSystemChatInputMention(
              label: messages.designSystemChatInputMentionWorkshop,
              color: tokens.colors.alert.warning.defaultColor,
            ),
            DesignSystemChatInputMention(
              label: messages.designSystemChatInputMentionWoodworking,
              color: tokens.colors.alert.success.defaultColor,
            ),
          ],
        ),
      ),
      (
        messages.designSystemChatInputRecordingLabel,
        input(phase: DesignSystemChatInputPhase.recording),
      ),
      (
        messages.designSystemChatInputTranscribingLabel,
        input(
          phase: DesignSystemChatInputPhase.transcribing,
          partial: messages.designSystemChatInputPartialSample,
        ),
      ),
      (
        messages.designSystemChatInputBusyLabel,
        input(busy: messages.designSystemChatInputBusySample),
      ),
      (
        messages.designSystemChatInputErrorLabel,
        input(
          text: messages.designSystemChatInputHintSample,
          error: messages.designSystemChatInputErrorSample,
        ),
      ),
    ];

    return ListView(
      padding: EdgeInsets.all(tokens.spacing.step6),
      children: [
        Text(
          messages.designSystemChatInputStatesTitle,
          style: tokens.typography.styles.heading.heading3.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step6),
        for (final (label, widget) in states)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: DesignSystemChatInputWidgetbook.maxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: tokens.spacing.step3,
                  children: [
                    Text(
                      label,
                      style: tokens.typography.styles.others.caption.copyWith(
                        color: tokens.colors.text.lowEmphasis,
                      ),
                    ),
                    widget,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
