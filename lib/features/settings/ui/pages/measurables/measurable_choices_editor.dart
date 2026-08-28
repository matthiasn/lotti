import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';

/// Edits the [MeasurableChoice] list of a choice-kind measurable.
///
/// The list is the user's vocabulary, so every operation keeps a choice's
/// id: renaming edits the title in place, reordering moves the row, and
/// "removing" archives it — an archived choice leaves the recording surfaces
/// but keeps resolving the entries that already recorded it, and can be
/// restored from the archived section below the list.
///
/// The widget owns nothing but the text controllers (one per choice id, so a
/// rebuild from the parent never resets a caret). The list itself is the
/// parent's state, handed back through [onChanged] after every edit,
/// **normalised** so active choices come first in display order and archived
/// ones trail — the reorderable list only shows the active ones, and that
/// invariant is what lets its indices address the full list directly.
class MeasurableChoicesEditor extends StatefulWidget {
  const MeasurableChoicesEditor({
    required this.choices,
    required this.onChanged,
    this.showErrors = false,
    this.newChoiceId = _newUuid,
    super.key,
  });

  /// Every choice, archived ones included.
  final List<MeasurableChoice> choices;

  /// Receives the whole list after each edit, active choices first.
  final ValueChanged<List<MeasurableChoice>> onChanged;

  /// Whether a blank title is called out as an error. Off while the user is
  /// still typing; the form turns it on after a save attempt failed.
  final bool showErrors;

  /// Mints the id of an added choice. Injectable so tests can predict it.
  final String Function() newChoiceId;

  /// Active choices in display order followed by the archived ones — the
  /// shape [onChanged] always reports, and what a caller should persist.
  static List<MeasurableChoice> normalize(List<MeasurableChoice> choices) => [
    for (final choice in choices)
      if (choice.archived != true) choice,
    for (final choice in choices)
      if (choice.archived == true) choice,
  ];

  static String _newUuid() => uuid.v4();

  @override
  State<MeasurableChoicesEditor> createState() =>
      _MeasurableChoicesEditorState();
}

class _MeasurableChoicesEditorState extends State<MeasurableChoicesEditor> {
  final _controllers = <String, TextEditingController>{};

  List<MeasurableChoice> get _active => [
    for (final choice in widget.choices)
      if (choice.archived != true) choice,
  ];

  List<MeasurableChoice> get _archived => [
    for (final choice in widget.choices)
      if (choice.archived == true) choice,
  ];

  TextEditingController _controllerFor(MeasurableChoice choice) =>
      _controllers.putIfAbsent(
        choice.id,
        () => TextEditingController(text: choice.title),
      );

  @override
  void didUpdateWidget(MeasurableChoicesEditor old) {
    super.didUpdateWidget(old);
    // A choice the parent dropped altogether (never the case for archive,
    // which keeps the row) must not leak its controller.
    final ids = {for (final choice in widget.choices) choice.id};
    for (final id in _controllers.keys.toList()) {
      if (!ids.contains(id)) _controllers.remove(id)!.dispose();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _emit(List<MeasurableChoice> choices) =>
      widget.onChanged(MeasurableChoicesEditor.normalize(choices));

  void _add() {
    _emit([
      ...widget.choices,
      MeasurableChoice(id: widget.newChoiceId(), title: ''),
    ]);
  }

  void _rename(MeasurableChoice choice, String title) {
    _emit([
      for (final existing in widget.choices)
        if (existing.id == choice.id)
          existing.copyWith(title: title)
        else
          existing,
    ]);
  }

  /// Archiving keeps the row where it was (it moves to the tail through
  /// normalisation); restoring appends the choice after the active ones, so
  /// a choice that comes back reads as newly added rather than silently
  /// reclaiming a slot in the middle of the order.
  void _setArchived(MeasurableChoice choice, {required bool archived}) {
    final updated = choice.copyWith(archived: archived);
    if (archived) {
      _emit([
        for (final existing in widget.choices)
          if (existing.id == choice.id) updated else existing,
      ]);
      return;
    }
    _emit([
      for (final existing in widget.choices)
        if (existing.id != choice.id) existing,
      updated,
    ]);
  }

  /// [newIndex] arrives already adjusted for the removed row, so the move
  /// is a plain remove-then-insert within the active prefix of the list.
  void _reorder(int oldIndex, int newIndex) {
    final active = _active;
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);
    _emit([...active, ..._archived]);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final active = _active;
    final archived = _archived;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsFormSection(
          title: messages.settingsMeasurableChoicesTitle,
          description: messages.settingsMeasurableChoicesDescription,
          children: [
            if (active.isEmpty)
              Text(
                messages.settingsMeasurableChoicesRequired,
                key: const ValueKey('measurable-choices-empty'),
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: widget.showErrors
                      ? tokens.colors.alert.error.ink
                      : tokens.colors.text.mediumEmphasis,
                ),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                proxyDecorator: (child, _, _) =>
                    Material(type: MaterialType.transparency, child: child),
                onReorderItem: _reorder,
                children: [
                  for (final (index, choice) in active.indexed)
                    Padding(
                      key: ValueKey('measurable-choice-row-${choice.id}'),
                      padding: EdgeInsets.only(
                        bottom: index == active.length - 1
                            ? 0
                            : tokens.spacing.cardItemSpacing,
                      ),
                      child: _ActiveChoiceRow(
                        index: index,
                        choice: choice,
                        controller: _controllerFor(choice),
                        showErrors: widget.showErrors,
                        onChanged: (title) => _rename(choice, title),
                        onArchive: () => _setArchived(choice, archived: true),
                      ),
                    ),
                ],
              ),
            InkWell(
              key: const ValueKey('measurable-choice-add'),
              onTap: _add,
              borderRadius: BorderRadius.circular(tokens.radii.m),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
                child: Row(
                  children: [
                    Icon(
                      LottiIcons.add,
                      size: IconSizes.m,
                      color: tokens.colors.interactive.enabled,
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Text(
                      messages.settingsMeasurableChoiceAdd,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.interactive.enabled),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (archived.isNotEmpty)
          SettingsFormSection(
            title: messages.settingsMeasurableChoicesArchivedTitle,
            description: messages.settingsMeasurableChoicesArchivedDescription,
            children: [
              for (final choice in archived)
                _ArchivedChoiceRow(
                  key: ValueKey('measurable-choice-archived-${choice.id}'),
                  choice: choice,
                  onRestore: () => _setArchived(choice, archived: false),
                ),
            ],
          ),
      ],
    );
  }
}

/// A drag handle, the editable title, and the archive action.
class _ActiveChoiceRow extends StatelessWidget {
  const _ActiveChoiceRow({
    required this.index,
    required this.choice,
    required this.controller,
    required this.showErrors,
    required this.onChanged,
    required this.onArchive,
  });

  final int index;
  final MeasurableChoice choice;
  final TextEditingController controller;
  final bool showErrors;
  final ValueChanged<String> onChanged;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final title = choice.title.trim();
    final name = title.isEmpty
        ? messages.settingsMeasurableChoiceNameHint
        : title;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The list merges each row into one accessibility node (its own
        // "move up / move down" actions are the reorder affordance there), so
        // the handle carries a tooltip — the hover text a pointer user gets —
        // rather than a label nothing would read.
        Tooltip(
          message: messages.settingsMeasurableChoiceReorder(name),
          child: ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: SizedBox(
                key: ValueKey('measurable-choice-drag-${choice.id}'),
                width: TapTargets.minimum,
                height: TapTargets.minimum,
                child: Icon(
                  LottiIcons.drag,
                  size: IconSizes.m,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step2),
        Expanded(
          child: DesignSystemTextInput(
            key: ValueKey('measurable-choice-title-${choice.id}'),
            controller: controller,
            hintText: messages.settingsMeasurableChoiceNameHint,
            semanticsLabel: messages.settingsMeasurableChoiceNameHint,
            textCapitalization: TextCapitalization.sentences,
            errorText: showErrors && title.isEmpty
                ? messages.settingsMeasurableChoiceNameRequired
                : null,
            onChanged: onChanged,
            trailingIcon: LottiIcons.archive,
            trailingIconTooltip: messages.settingsMeasurableChoiceArchive(name),
            trailingIconKey: ValueKey('measurable-choice-archive-${choice.id}'),
            onTrailingIconTap: onArchive,
          ),
        ),
      ],
    );
  }
}

/// A retired choice: its title, dimmed, and a restore action.
class _ArchivedChoiceRow extends StatelessWidget {
  const _ArchivedChoiceRow({
    required this.choice,
    required this.onRestore,
    super.key,
  });

  final MeasurableChoice choice;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      children: [
        Expanded(
          child: Text(
            choice.title,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        DesignSystemIconAction(
          key: ValueKey('measurable-choice-restore-${choice.id}'),
          icon: LottiIcons.unarchive,
          tooltip: messages.settingsMeasurableChoiceRestore(choice.title),
          onPressed: onRestore,
        ),
      ],
    );
  }
}
