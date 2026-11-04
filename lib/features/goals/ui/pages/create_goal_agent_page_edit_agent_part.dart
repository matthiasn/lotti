part of 'create_goal_agent_page.dart';

/// The goal's agent on the single edit page: how it answers and its name,
/// under the statement, signals and name — the fields creation's
/// confirmation step asks for, here on the same page as everything else so
/// an edit is one scroll and one *Save new version*.
class _EditAgentSection extends StatelessWidget {
  const _EditAgentSection({
    required this.persona,
    required this.personaError,
    required this.onPersonaChanged,
    required this.enabled,
    required this.checkInsAreSubstance,
    required this.onCheckInsAreSubstanceChanged,
  });

  /// The section as [form] stands.
  factory _EditAgentSection.of(_CreateGoalAgentPageState form) =>
      _EditAgentSection(
        persona: form._persona,
        personaError: form._personaError,
        onPersonaChanged: form._clearPersonaError,
        enabled: !form._saving,
        checkInsAreSubstance: form._shownCheckInsAreSubstance,
        onCheckInsAreSubstanceChanged: form._setCheckInsAreSubstance,
      );

  final TextEditingController persona;
  final String? personaError;
  final VoidCallback onPersonaChanged;
  final bool enabled;

  /// Whether the check-ins are the goal itself (ADR 0151) — a setting of
  /// how the agent answers, so it sits here, as the person editor's
  /// reminders switch sits in theirs.
  final bool checkInsAreSubstance;
  final ValueChanged<bool> onCheckInsAreSubstanceChanged;

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
          AgentSwitchRow(
            title: messages.goalFormCheckInsAreSubstanceTitle,
            toggleKey: const ValueKey('goal-form-check-ins-are-substance'),
            value: checkInsAreSubstance,
            onChanged: onCheckInsAreSubstanceChanged,
            body: Text(messages.goalFormCheckInsAreSubstanceSubtitle),
          ),
          SizedBox(height: tokens.spacing.step5),
          DesignSystemTextInput(
            key: const ValueKey('goal-form-persona'),
            controller: persona,
            label: messages.goalFormPersonaLabel,
            errorText: personaError,
            enabled: enabled,
            onChanged: (_) => onPersonaChanged(),
          ),
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
      // What the switch shows, not the raw override: switching it off and
      // on again is no change.
      _shownCheckInsAreSubstance,
      _compositeRule,
      _requiredSuccesses,
    ].join('\u0000');
  }

  /// Keeps the edit's starting point. It is taken as soon as the goal is on
  /// the form — the fields are editable from then on — and moved along with
  /// what the app fills in by itself afterwards (the goal row's category,
  /// catalog clean-ups as habits and measurables load), but only while the
  /// form was untouched on the previous build: every edit rebuilds the page,
  /// so a change typed before loading finished is seen first and stays a
  /// change.
  void _settleEditBaseline({required bool habitsLoaded}) {
    if (!_editing || !_initialized) return;
    final loading = [
      _categoryInitialized,
      habitsLoaded,
      _measurableDefinitionsLoaded,
    ].join(',');
    final now = _editFingerprint();
    final baseline = _editBaseline;
    if (baseline == null ||
        (loading != _editLoadingSeen && _editLastSeen == baseline)) {
      _editBaseline = now;
    }
    _editLoadingSeen = loading;
    _editLastSeen = now;
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

/// The goal's category on the single edit page, filed under its name. It
/// cannot be changed until the goal row's own category has read.
Widget _editCategoryField(_CreateGoalAgentPageState form) => IgnorePointer(
  ignoring: form._saving,
  child: CategoryFieldRow(
    categoryId: form._categoryId,
    onChanged: form._categoryChanger,
  ),
);
