part of 'create_goal_agent_page.dart';

/// The goal's agent on the single edit page: its name and the goal's
/// category, under the statement, signals and name — the fields creation's
/// confirmation step asks for, here on the same page as everything else so
/// an edit is one scroll and one *Save new version*.
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

  /// The section as [form] stands, editing [spec].
  factory _EditAgentSection.of(
    _CreateGoalAgentPageState form,
    GoalSpecVersionEntity? spec,
  ) => _EditAgentSection(
    persona: form._persona,
    personaError: form._personaError,
    onPersonaChanged: form._clearPersonaError,
    enabled: !form._saving,
    categoryId: form._categoryId,
    onCategoryChanged: form._categoryChanger,
    editVersion: spec?.version,
  );

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
    // The shared section a person's form ends on too, so both editors close
    // on the same *Your agent*.
    return AgentFormSection(
      key: const ValueKey('goal-form-agent-section'),
      title: messages.agentFormSectionTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
      ),
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

/// Leaving the single edit page with changes on it asks first, as the person
/// editor does: the back button, *Cancel* and the system back all come
/// through [_CreateGoalAgentPageState._back].
extension _GoalEditLeave on _CreateGoalAgentPageState {
  /// Everything an edit can change, in an order-free form: a signal ticked
  /// off and on again is no change.
  String _editFingerprint() {
    String sorted(Map<String, Object?> map) =>
        (map.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join(
          ',',
        );
    return [
      _statement.text,
      _title.text,
      _persona.text,
      _categoryId,
      sorted(_habitTargets),
      sorted(_measurableTargets),
      sorted(_healthTargets),
      sorted(_healthDirections),
      sorted(_categoryTimeTargets),
      sorted(_categoryTimeDirections),
      sorted(_labelTimeTargets),
      sorted(_labelTimeDirections),
      sorted(_labelTimeCategoryIds),
      _watchesSteps,
      _stepsTarget.text,
      _watchesCheckInTime,
      _checkInMinutes.text,
      _checkInsAreSubstance,
      _compositeRule,
      _requiredSuccesses,
    ].join('\u0000');
  }

  /// Takes the edit's starting point once the goal and the catalogs it is
  /// read against have loaded, so their arrival is never mistaken for an
  /// edit.
  void _settleEditBaseline({required bool loaded}) {
    if (!_editing || !_initialized || !loaded) return;
    if (!_measurableDefinitionsLoaded) return;
    _editBaseline ??= _editFingerprint();
  }

  bool get _editLeaveNeedsConfirm =>
      _editing &&
      !_saving &&
      _editBaseline != null &&
      _editFingerprint() != _editBaseline;

  Future<void> _confirmLeaveEdit() async {
    final messages = context.messages;
    final confirmed = await showConfirmationModal(
      context: context,
      message: messages.goalFormDiscardChangesMessage,
      confirmLabel: messages.editorDiscardChanges,
    );
    if (!confirmed || !mounted) return;
    beamToNamed(goalDetailPath(widget.agentId!));
  }
}

/// The form's footer: always on screen, on an opaque band — scrolling
/// content ends at a hairline instead of being guillotined behind a floating
/// pill. The primary action is as wide as its label, on the trailing edge
/// where a form's forward action sits; editing puts *Cancel* on the leading
/// edge, as the person editor's footer does.
class _GoalFormFooter extends StatelessWidget {
  const _GoalFormFooter({required this.primary, required this.onCancel});

  final Widget primary;

  /// Null while creating, where the app bar's back button walks the steps.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: tokens.spacing.step4,
          bottom:
              tokens.spacing.step4 +
              DesignSystemBottomNavigationBar.occupiedHeight(context),
        ),
        child: DesignSystemModalActionBar(
          layout: DesignSystemModalActionBarLayout.compactPrimary,
          secondary: [
            if (onCancel case final onCancel?)
              DesignSystemButton(
                key: const ValueKey('goal-form-cancel'),
                label: context.messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: onCancel,
              ),
          ],
          primary: primary,
        ),
      ),
    );
  }
}
