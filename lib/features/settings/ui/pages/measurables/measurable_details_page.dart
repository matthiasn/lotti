import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/aggregation_label.dart';
import 'package:lotti/features/settings/ui/pages/measurables/measurable_choices_editor.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/features/settings/ui/widgets/form/settings_form_text_field.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_detail_scaffold.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_form_section.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Measurable data type editor on the shared settings-detail kit.
///
/// The form mechanics are unchanged: a local `FormBuilder` key plus a
/// `dirty` flag gate the save action, and save reads the form values into
/// a `copyWith` on the edited [MeasurableDataType]. The value kind and the
/// choice list live beside the form as plain widget state — the kind
/// decides which fields the form shows (unit and aggregation are numeric
/// affairs), and the choices are a list the form kit has no field for —
/// and flip the same `dirty` flag. Navigation (back,
/// cancel, after save/delete) beams to `/settings/measurables` rather
/// than popping — V2's desktop detail surface mounts the page inline (no
/// Navigator route to pop); on mobile the URL change still pops the page
/// off the Beamer stack.
class MeasurableDetailsPage extends StatefulWidget {
  const MeasurableDetailsPage({
    required this.dataType,
    this.isCreateMode = false,
    super.key,
  });

  final MeasurableDataType dataType;

  /// Create flow (`CreateMeasurablePage`) hides the destructive delete
  /// action and uses the create title/label.
  final bool isCreateMode;

  @override
  State<MeasurableDetailsPage> createState() {
    return _MeasurableDetailsPageState();
  }
}

class _MeasurableDetailsPageState extends State<MeasurableDetailsPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  late MeasurableValueKind _valueKind =
      widget.dataType.valueKind ?? MeasurableValueKind.number;
  late List<MeasurableChoice> _choices = MeasurableChoicesEditor.normalize(
    widget.dataType.choices ?? const [],
  );

  /// Set by a save attempt that a blank or missing choice blocked, so the
  /// editor calls those rows out until the user fixes them.
  bool _showChoiceErrors = false;

  bool get _isChoice => _valueKind == MeasurableValueKind.choice;

  void _setValueKind(MeasurableValueKind kind) {
    setState(() {
      _valueKind = kind;
      dirty = true;
    });
  }

  void _setChoices(List<MeasurableChoice> choices) {
    setState(() {
      _choices = choices;
      dirty = true;
    });
  }

  /// A choice measurable needs at least one active choice, and every active
  /// choice needs a name — an unnamed choice would record as a blank chip.
  bool get _choicesValid {
    final active = [
      for (final choice in _choices)
        if (choice.archived != true) choice,
    ];
    return active.isNotEmpty &&
        active.every((choice) => choice.title.trim().isNotEmpty);
  }

  /// Opens a single-page modal listing every [AggregationType] under its
  /// localized name; picking one writes it into the form [field].
  Future<void> _pickAggregationType(
    FormFieldState<AggregationType> field,
  ) {
    return ModalUtils.showSinglePageModal<void>(
      context: context,
      title: context.messages.settingsMeasurableAggregationLabel,
      builder: (BuildContext modalContext) {
        final spacing = modalContext.designTokens.spacing;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.step3,
            vertical: spacing.step5,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final aggregationType in AggregationType.values)
                SettingsCard(
                  onTap: () {
                    field.didChange(aggregationType);
                    Navigator.pop(modalContext);
                  },
                  title: aggregationTypeLabel(
                    modalContext.messages,
                    aggregationType,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    // Beam back to the measurables list rather than popping. The page
    // is mounted inline inside V2's desktop detail surface (no
    // Navigator route to pop); on mobile the URL change still pops the
    // page off the Beamer stack.
    void backToList() => beamToNamed('/settings/measurables');

    final item = widget.dataType;

    Future<void> onSavePressed() async {
      _formKey.currentState!.save();
      final formValid = _formKey.currentState!.validate();
      if (_isChoice && !_choicesValid) {
        setState(() => _showChoiceErrors = true);
        return;
      }
      if (formValid) {
        final formData = _formKey.currentState?.value;
        final private = formData?['private'] as bool? ?? false;
        final favorite = formData?['favorite'] as bool? ?? false;
        final dataType = item.copyWith(
          description: '${formData!['description']}'.trim(),
          // Unit and aggregation are numeric fields the choice form does not
          // show; a choice measurable keeps whatever it had.
          unitName: _isChoice
              ? item.unitName
              : '${formData['unitName']}'.trim(),
          displayName: '${formData['displayName']}'.trim(),
          private: private,
          favorite: favorite,
          aggregationType: _isChoice
              ? item.aggregationType
              : formData['aggregationType'] as AggregationType?,
          valueKind: _valueKind,
          // A numeric measurable that never had choices stays without the
          // key rather than gaining an empty list on every save.
          choices: _choices.isEmpty
              ? null
              : [
                  for (final choice in _choices)
                    choice.copyWith(title: choice.title.trim()),
                ],
        );

        await persistenceLogic.upsertEntityDefinition(dataType);
        setState(() {
          dirty = false;
        });

        backToList();
      }
    }

    Future<void> onDeletePressed() async {
      const deleteKey = 'deleteKey';
      final result = await showModalActionSheet<String>(
        context: context,
        title: messages.measurableDeleteQuestion,
        actions: [
          ModalSheetAction(
            icon: LottiIcons.warning,
            label: messages.measurableDeleteConfirm,
            key: deleteKey,
            isDestructiveAction: true,
          ),
        ],
      );

      if (result == deleteKey) {
        await persistenceLogic.upsertEntityDefinition(
          item.copyWith(deletedAt: DateTime.now()),
        );

        backToList();
      }
    }

    return SettingsDetailScaffold(
      title: widget.isCreateMode
          ? messages.settingsMeasurablesCreateTitle
          : messages.settingsMeasurableDetailsLabel,
      onBack: backToList,
      onSaveShortcut: () {
        if (dirty) onSavePressed();
      },
      saveShortcutEnabled: () => dirty,
      actionBar: SettingsFormActionBar(
        primaryLabel: widget.isCreateMode
            ? messages.createButton
            : messages.saveButton,
        onPrimary: onSavePressed,
        primaryEnabled: dirty,
        secondaryLabel: messages.cancelButton,
        onSecondary: backToList,
      ),
      deleteLabel: widget.isCreateMode ? null : messages.deleteButton,
      onDelete: widget.isCreateMode ? null : onDeletePressed,
      children: [
        FormBuilder(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: () {
            setState(() {
              dirty = true;
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsFormSection(
                title: messages.basicSettings,
                children: [
                  SettingsFormTextField(
                    key: const Key('measurable_name_field'),
                    initialValue: item.displayName,
                    labelText: messages.settingsMeasurableNameLabel,
                    name: 'displayName',
                    semanticsLabel: messages.settingsMeasurableNameLabel,
                    autofocus: widget.isCreateMode,
                  ),
                  SettingsFormTextField(
                    key: const Key('measurable_description_field'),
                    initialValue: item.description,
                    labelText: messages.settingsMeasurableDescriptionLabel,
                    fieldRequired: false,
                    multiline: true,
                    name: 'description',
                    semanticsLabel: messages.settingsMeasurableDescriptionLabel,
                  ),
                  _ValueKindField(
                    valueKind: _valueKind,
                    onChanged: _setValueKind,
                  ),
                  if (!_isChoice) ...[
                    SettingsFormTextField(
                      initialValue: item.unitName,
                      labelText: messages.settingsMeasurableUnitLabel,
                      fieldRequired: false,
                      name: 'unitName',
                      semanticsLabel: messages.settingsMeasurableUnitLabel,
                    ),
                    FormBuilderField<AggregationType>(
                      name: 'aggregationType',
                      initialValue: item.aggregationType,
                      builder: (field) {
                        final value = field.value;
                        return SettingsPickerField(
                          key: const Key('measurable_aggregation_field'),
                          label: messages.settingsMeasurableAggregationLabel,
                          valueText: value != null
                              ? aggregationTypeLabel(messages, value)
                              : null,
                          hintText: messages.aggregationNone,
                          helperText:
                              messages.settingsMeasurableAggregationHelper,
                          semanticsLabel:
                              messages.settingsMeasurableAggregationLabel,
                          onTap: () => _pickAggregationType(field),
                        );
                      },
                    ),
                  ],
                ],
              ),
              if (_isChoice)
                MeasurableChoicesEditor(
                  choices: _choices,
                  showErrors: _showChoiceErrors,
                  onChanged: _setChoices,
                ),
              SettingsFormSection(
                title: messages.habitSectionOptionsTitle,
                children: [
                  FormSwitch(
                    name: 'favorite',
                    initialValue: item.favorite ?? false,
                    title: messages.favoriteLabel,
                    icon: LottiIcons.star,
                  ),
                  FormSwitch(
                    name: 'private',
                    initialValue: item.private,
                    title: messages.privateLabel,
                    subtitle: messages.privateSwitchDescription,
                    icon: LottiIcons.lock,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Recorded as": the number / choice switch with its helper line, styled
/// like the kit's labelled fields so it sits naturally between them.
class _ValueKindField extends StatelessWidget {
  const _ValueKindField({required this.valueKind, required this.onChanged});

  final MeasurableValueKind valueKind;
  final ValueChanged<MeasurableValueKind> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          messages.settingsMeasurableValueKindLabel,
          style: tokens.typography.styles.subtitle.subtitle2.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
        DsSegmentedToggle<MeasurableValueKind>(
          key: const Key('measurable_value_kind_field'),
          expand: true,
          selected: valueKind,
          onChanged: onChanged,
          segments: [
            DsSegment(
              MeasurableValueKind.number,
              messages.settingsMeasurableValueKindNumber,
            ),
            DsSegment(
              MeasurableValueKind.choice,
              messages.settingsMeasurableValueKindChoice,
            ),
          ],
        ),
        SizedBox(height: tokens.spacing.step2),
        Text(
          messages.settingsMeasurableValueKindHelper,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ],
    );
  }
}

class EditMeasurablePage extends StatelessWidget {
  EditMeasurablePage({
    required this.measurableId,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String measurableId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MeasurableDataType?>(
      stream: notificationDrivenItemStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {measurablesNotification, privateToggleNotification},
        fetcher: () => _db.getMeasurableDataTypeById(measurableId),
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<MeasurableDataType?> snapshot,
          ) {
            final dataType = snapshot.data;

            if (dataType == null) {
              return EmptyScaffoldWithTitle(
                context.messages.measurableNotFound,
              );
            }

            return MeasurableDetailsPage(
              dataType: dataType,
            );
          },
    );
  }
}
