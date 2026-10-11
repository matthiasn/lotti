part of 'check_in_capture_sheet.dart';

/// The form's facts and details in the app's create-form grammar
/// (`ProjectCreateForm`): a rule, then one settings row per fact — icon,
/// noun, value, chevron — ruled apart, each opening the same picker the
/// check-in page uses, at the list's compact size so the facts and the
/// details fit one phone screen; then the details row, folding out the
/// three text details as the design system's own labelled fields.
///
/// Presentational: the form owns every value and hands in what each row
/// opens. Held — shown, no tap — while [enabled] is false.
class _CheckInFactRows extends StatelessWidget {
  const _CheckInFactRows({
    required this.interactionType,
    required this.startedLabel,
    required this.duration,
    required this.sentiment,
    required this.detailsCaption,
    required this.detailsOpen,
    required this.enabled,
    required this.onPickType,
    required this.onPickStart,
    required this.onPickDuration,
    required this.onPickSentiment,
    required this.onToggleDetails,
    required this.topicsController,
    required this.payAttentionController,
    required this.avoidController,
  });

  final CheckInInteractionType interactionType;
  final String startedLabel;
  final Duration duration;
  final CheckInSentiment? sentiment;

  /// What the details hold — `2 topics · next time noted`, or *Not set*.
  final String detailsCaption;
  final bool detailsOpen;
  final bool enabled;
  final VoidCallback onPickType;
  final VoidCallback onPickStart;
  final VoidCallback onPickDuration;
  final VoidCallback onPickSentiment;
  final VoidCallback onToggleDetails;
  final TextEditingController topicsController;
  final TextEditingController payAttentionController;
  final TextEditingController avoidController;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final notSet = messages.checkInRowNotSet;
    final ink = tokens.colors.text.mediumEmphasis;
    final sentiment = this.sentiment;
    VoidCallback? live(VoidCallback onTap) => enabled ? onTap : null;

    Widget row({
      required String key,
      required IconData icon,
      required String title,
      required String value,
      required VoidCallback onTap,
      Color? iconColor,
    }) => DesignSystemSelectionRow(
      key: ValueKey(key),
      title: title,
      subtitle: value,
      type: DesignSystemSelectionRowType.navigation,
      size: DesignSystemListItemSize.small,
      leading: Icon(icon, color: iconColor ?? ink),
      onTap: live(onTap),
    );

    // Each text detail is the design system's own labelled field, unfilled
    // on the sheet like the note, one `step5` apart.
    Widget field({
      required String key,
      required TextEditingController controller,
      required String label,
      String? hint,
    }) => DesignSystemTextInput(
      key: ValueKey(key),
      controller: controller,
      label: label,
      semanticsLabel: label,
      hintText: hint,
      textCapitalization: TextCapitalization.sentences,
      filled: false,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const DesignSystemDivider(),
        row(
          key: 'check-in-type',
          icon: checkInInteractionIcon(interactionType),
          title: messages.checkInRowType,
          value: checkInInteractionLabel(context, interactionType),
          onTap: onPickType,
        ),
        const DesignSystemDivider(),
        row(
          key: 'check-in-started',
          icon: LottiIcons.today,
          title: messages.checkInStartedLabel,
          value: startedLabel,
          onTap: onPickStart,
        ),
        const DesignSystemDivider(),
        row(
          key: 'check-in-duration',
          icon: LottiIcons.timer,
          title: messages.checkInDurationChip,
          value: duration == Duration.zero
              ? notSet
              : checkInDurationLabel(context, duration),
          onTap: onPickDuration,
        ),
        const DesignSystemDivider(),
        // Unset reads *Not set* like every other fact; that the feeling is
        // optional and never the agent's is said in its picker, where it is
        // chosen.
        row(
          key: 'check-in-sentiment',
          icon: sentiment == null
              ? LottiIcons.moodNeutral
              : sentimentGlyph(sentiment),
          iconColor: sentiment == null
              ? null
              : sentimentColor(tokens, sentiment),
          title: messages.checkInMoreCaptionFeeling,
          value: sentiment == null
              ? notSet
              : checkInSentimentLabel(context, sentiment),
          onTap: onPickSentiment,
        ),
        const DesignSystemDivider(),
        // The text details fold under one more row that says what they hold
        // — open from the start when editing, or when the draft already
        // holds any — so both sheets keep one structure and the group always
        // has its heading and a way to fold back.
        DesignSystemSelectionRow(
          key: const ValueKey('check-in-more'),
          title: messages.checkInRowDetails,
          subtitle: detailsCaption,
          type: DesignSystemSelectionRowType.action,
          size: DesignSystemListItemSize.small,
          leading: Icon(LottiIcons.label, color: ink),
          trailing: Icon(
            detailsOpen ? LottiIcons.chevronUp : LottiIcons.chevronDown,
            color: ink,
            size: tokens.spacing.step6,
          ),
          semanticLabel: messages.checkInRowDetails,
          onTap: live(onToggleDetails),
        ),
        if (detailsOpen) ...[
          const DesignSystemDivider(),
          SizedBox(height: tokens.spacing.step5),
          field(
            key: 'check-in-topics',
            controller: topicsController,
            label: messages.checkInTopicsLabel,
            hint: messages.checkInTopicsHint,
          ),
          SizedBox(height: tokens.spacing.step5),
          field(
            key: 'check-in-pay-attention',
            controller: payAttentionController,
            label: messages.checkInPayAttentionLabel,
          ),
          SizedBox(height: tokens.spacing.step5),
          field(
            key: 'check-in-avoid',
            controller: avoidController,
            label: messages.checkInAvoidLabel,
          ),
        ],
      ],
    );
  }
}
