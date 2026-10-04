part of 'create_goal_agent_page.dart';

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.steps, required this.step});

  /// The steps this flow actually walks — two for editing, three for
  /// creation — so the dots and the caption promise the same count.
  final List<_GoalFormStep> steps;
  final _GoalFormStep step;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final position = steps.indexOf(step);
    final label = context.messages.goalFormProgress(
      position + 1,
      steps.length,
    );
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final candidate in steps) ...[
                  AnimatedContainer(
                    duration: MotionDurations.short4,
                    width: candidate == step
                        ? tokens.spacing.step5
                        : tokens.spacing.step2,
                    height: tokens.spacing.step2,
                    decoration: BoxDecoration(
                      // lowEmphasis ink, not a decorative hairline tone:
                      // the promise of the remaining steps must survive the
                      // dark canvas.
                      color: steps.indexOf(candidate) <= position
                          ? tokens.colors.interactive.enabled
                          : tokens.colors.text.lowEmphasis,
                      borderRadius: BorderRadius.circular(
                        tokens.radii.badgesPills,
                      ),
                    ),
                  ),
                  if (candidate != steps.last)
                    SizedBox(width: tokens.spacing.step2),
                ],
              ],
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              label,
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentionStep extends StatelessWidget {
  const _IntentionStep({
    required this.controller,
    required this.validation,
    required this.onExampleSelected,
  });

  final TextEditingController controller;
  final String? validation;
  final ValueChanged<String> onExampleSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final examples = _intentionExamples(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.goalFormIntentionPrompt,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.goalFormIntentionHelper,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextarea(
          fieldKey: const ValueKey('goal-form-intention'),
          controller: controller,
          hintText: messages.goalFormIntentionHint,
          errorText: validation,
          minLines: 4,
          growWithContent: true,
        ),
        SizedBox(height: tokens.spacing.step4),
        Wrap(
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final example in examples)
              DsPill(
                variant: DsPillVariant.filled,
                label: example,
                bordered: true,
                onTap: () => onExampleSelected(example),
              ),
          ],
        ),
      ],
    );
  }
}

class _ConfirmationStep extends StatefulWidget {
  const _ConfirmationStep({
    required this.title,
    required this.persona,
    required this.signalDescription,
    required this.preservesCriteria,
    required this.editVersion,
    required this.validation,
    required this.personaError,
    required this.titleError,
    required this.onPersonaChanged,
    required this.onTitleChanged,
    required this.enabled,
  });

  final TextEditingController title;
  final TextEditingController persona;
  final String signalDescription;
  final bool preservesCriteria;
  final int? editVersion;
  final String? validation;
  final String? personaError;
  final String? titleError;
  final VoidCallback onPersonaChanged;
  final VoidCallback onTitleChanged;
  final bool enabled;

  @override
  State<_ConfirmationStep> createState() => _ConfirmationStepState();
}

/// A CONFIRMATION, not more form: the plain-language summary is the hero,
/// the goal name reads as a text row with an edit affordance (it was fully
/// editable one step ago), the persona field follows, and the cost note is
/// a caption, not a card competing with the summary.
class _ConfirmationStepState extends State<_ConfirmationStep> {
  bool _editingTitle = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // A validation error re-opens the field so the fix is one tap closer.
    final editingTitle = _editingTitle || widget.titleError != null;
    // "Meet your agent" leads with the agent; the recap reads as prose in
    // which only the signals carry weight, and the goal name closes the
    // card as a read-only record.
    final restatementParts = messages
        .goalFormRestatement('\u0000')
        .split('\u0000');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.goalFormConfirmTitle,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextInput(
          key: const ValueKey('goal-form-persona'),
          controller: widget.persona,
          label: messages.goalFormPersonaLabel,
          leadingIcon: LottiIcons.aiSpark,
          errorText: widget.personaError,
          enabled: widget.enabled,
          onChanged: (_) => widget.onPersonaChanged(),
        ),
        SizedBox(height: tokens.spacing.step4),
        DesignSystemSectionCard(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.preservesCriteria)
                Text(
                  messages.goalFormPreservedCriteriaSummary,
                  style: tokens.typography.styles.body.bodyMedium.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                )
              else
                Text.rich(
                  TextSpan(
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                    children: [
                      TextSpan(text: restatementParts.first),
                      TextSpan(
                        text: widget.signalDescription,
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.highEmphasis,
                              fontWeight: tokens.typography.weight.semiBold,
                            ),
                      ),
                      for (final part in restatementParts.skip(1))
                        TextSpan(text: part),
                    ],
                  ),
                ),
              SizedBox(height: tokens.spacing.step4),
              // ONE field grammar across steps: the same labelled input as
              // the mapping step, read-only until the pencil (or a
              // validation error) unlocks it.
              DesignSystemTextInput(
                key: const ValueKey('goal-form-title'),
                controller: widget.title,
                label: messages.goalFormGoalNameLabel,
                leadingIcon: LottiIcons.flag,
                errorText: widget.titleError,
                enabled: widget.enabled,
                readOnly: !editingTitle,
                trailingIcon: editingTitle ? null : LottiIcons.edit,
                trailingIconTooltip: editingTitle
                    ? null
                    : messages.goalFormGoalNameLabel,
                trailingIconKey: const ValueKey('goal-form-title-edit'),
                onTrailingIconTap: editingTitle
                    ? null
                    : () => setState(() => _editingTitle = true),
                onChanged: (_) => widget.onTitleChanged(),
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spacing.step4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LottiIcons.eco,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                messages.goalFormCostHonesty,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ],
        ),
        if (widget.validation != null) ...[
          SizedBox(height: tokens.spacing.step3),
          Text(
            widget.validation!,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.alert.error.defaultColor,
            ),
          ),
        ],
        if (widget.editVersion != null) ...[
          SizedBox(height: tokens.spacing.step4),
          Text(
            messages.goalFormEditVersion(widget.editVersion! + 1),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
        SizedBox(height: tokens.spacing.step4),
        Text(
          messages.goalFormFooter,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}
