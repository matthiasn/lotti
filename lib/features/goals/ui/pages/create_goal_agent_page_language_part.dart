part of 'create_goal_agent_page.dart';

/// The language the goal's agent writes its briefings in, on the edit page's
/// *Your agent* section.
///
/// Null is *Automatic*: the briefings follow the goal's journal — the
/// default language of the category the goal is filed in, read from the
/// category picked on this very form, so moving the goal shows the language
/// it will move to. A language picked by hand stands; when the journal's
/// language moves away from it, the field offers the journal's instead,
/// without applying it (`goalBriefingLanguageSuggestion`).
class _GoalBriefingLanguageField extends StatelessWidget {
  const _GoalBriefingLanguageField({
    required this.chosen,
    required this.journal,
    required this.onChanged,
  });

  /// The language picked for the goal; null follows [journal].
  final String? chosen;

  /// The goal's journal language, or null when its category names none.
  final String? journal;

  /// Null while the form cannot be changed (a save in flight).
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final shown = resolveGoalBriefingLanguage(chosen: chosen, journal: journal);
    final language = shown.language;
    final value = switch (shown.source) {
      GoalBriefingLanguageSource.chosen => language!.localizedName(context),
      GoalBriefingLanguageSource.journal =>
        messages.goalFormBriefingLanguageAutomaticNamed(
          language!.localizedName(context),
        ),
      GoalBriefingLanguageSource.unset =>
        messages.goalFormBriefingLanguageAutomatic,
    };
    final suggestion = goalBriefingLanguageSuggestion(
      chosen: chosen,
      journal: journal,
    );
    final onChanged = this.onChanged;
    final caption = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignSystemPickerField(
          fieldKey: const ValueKey('goal-form-briefing-language'),
          label: messages.goalFormBriefingLanguageLabel,
          value: value,
          placeholder: messages.goalFormBriefingLanguageAutomatic,
          leading: language == null
              ? null
              : buildLanguageFlag(
                  languageCode: language.code,
                  height: IconSizes.m,
                  width: tokens.spacing.step6,
                ),
          // The picker's own *Clear* row returns the goal to Automatic.
          onTap: onChanged == null
              ? null
              : () => showLanguageSelectionModal(
                  context: context,
                  initialLanguageCode: chosen,
                  onSelected: (code) async => onChanged(code),
                  headerPadding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.step3,
                  ),
                ),
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(messages.goalFormBriefingLanguageHelper, style: caption),
        if (suggestion != null) ...[
          SizedBox(height: tokens.spacing.step3),
          // The offer, then the action that takes it on a line of its own:
          // an inline action fills the width it is given, so it never shares
          // a row with the caption it answers.
          Text(
            messages.goalFormBriefingLanguageSuggestion(
              suggestion.localizedName(context),
            ),
            style: caption,
          ),
          DesignSystemInlineAction(
            key: const ValueKey('goal-form-briefing-language-use-journal'),
            label: messages.goalFormBriefingLanguageUse(
              suggestion.localizedName(context),
            ),
            semanticsLabel: messages.goalFormBriefingLanguageUse(
              suggestion.localizedName(context),
            ),
            // The accent and the glyph make it read as the offer's answer,
            // not as one more line of caption.
            leadingIcon: LottiIcons.language,
            ink: tokens.colors.interactive.enabled,
            onTap: onChanged == null ? null : () => onChanged(suggestion.code),
          ),
        ],
      ],
    );
  }
}

/// The form's half of the briefing language: what the journal says, and
/// saving the pick (`_setLanguage` sits on the state, beside `setState`).
extension _GoalFormLanguage on _CreateGoalAgentPageState {
  /// The journal language of the category picked on the form — the one the
  /// goal will be filed in once saved. The build watches the categories, so
  /// a category's language changing in Settings reaches the field live.
  String? get _journalLanguageCode {
    final categoryId = _categoryId;
    if (categoryId == null) return null;
    return ref
        .read(categoriesStreamProvider)
        .value
        ?.where((category) => category.id == categoryId)
        .firstOrNull
        ?.defaultLanguageCode;
  }

  /// Saves a changed briefing language on the agent's identity. Separate from
  /// the spec revision on purpose: the language is the agent's setting, and
  /// a language-only edit must not mint a version (see
  /// `GoalAgentService.updateBriefingLanguage`).
  Future<void> _saveLanguageIfChanged(
    ProviderContainer container,
    String agentId,
  ) async {
    if (_languageCode == _initialLanguageCode) return;
    await container
        .read(goalAgentServiceProvider)
        .updateBriefingLanguage(agentId: agentId, languageCode: _languageCode);
    _initialLanguageCode = _languageCode;
  }
}
