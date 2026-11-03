part of 'create_goal_agent_page.dart';

/// The goal's agent on the single edit page: its name and the goal's
/// category, under the statement, signals and name — the fields creation's
/// confirmation step asks for, here on the same page as everything else so
/// an edit is one scroll and one *Save changes*.
class _EditAgentSection extends StatelessWidget {
  const _EditAgentSection({
    required this.persona,
    required this.personaError,
    required this.onPersonaChanged,
    required this.enabled,
    required this.categoryId,
    required this.onCategoryChanged,
    required this.editVersion,
  });

  final TextEditingController persona;
  final String? personaError;
  final VoidCallback onPersonaChanged;
  final bool enabled;
  final String? categoryId;

  /// Null while the goal's category has not been read yet.
  final ValueChanged<String?>? onCategoryChanged;

  /// The version being edited; the save starts the next one, and the page
  /// says so, with the history kept.
  final int? editVersion;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      key: const ValueKey('goal-form-agent-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.goalFormAgentSectionTitle,
          style: tokens.typography.styles.heading.heading3,
        ),
        SizedBox(height: tokens.spacing.step5),
        DesignSystemTextInput(
          key: const ValueKey('goal-form-persona'),
          controller: persona,
          label: messages.goalFormPersonaLabel,
          leadingIcon: LottiIcons.aiSpark,
          errorText: personaError,
          enabled: enabled,
          onChanged: (_) => onPersonaChanged(),
        ),
        SizedBox(height: tokens.spacing.step4),
        IgnorePointer(
          ignoring: !enabled,
          child: CategoryFieldRow(
            categoryId: categoryId,
            onChanged: onCategoryChanged,
          ),
        ),
        if (editVersion case final version?) ...[
          SizedBox(height: tokens.spacing.step5),
          Text(
            messages.goalFormEditVersion(version + 1),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ],
    );
  }
}

/// The edit page before the goal it edits has loaded, or once it cannot be:
/// the page's own title and way back over a spinner, or over the reason.
class _EditLoadScaffold extends StatelessWidget {
  const _EditLoadScaffold({required this.onBack, required this.unavailable});

  final VoidCallback onBack;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: onBack),
        title: Text(messages.goalFormEditTitle),
      ),
      body: Center(
        child: unavailable
            ? Padding(
                padding: EdgeInsets.all(tokens.spacing.step5),
                child: Text(
                  messages.goalDetailHealthUnavailable,
                  textAlign: TextAlign.center,
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
