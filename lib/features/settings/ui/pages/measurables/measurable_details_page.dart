import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/aggregation_label.dart';
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
/// a `copyWith` on the edited [MeasurableDataType]. Navigation (back,
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
      if (_formKey.currentState!.validate()) {
        final formData = _formKey.currentState?.value;
        final private = formData?['private'] as bool? ?? false;
        final favorite = formData?['favorite'] as bool? ?? false;
        final dataType = item.copyWith(
          description: '${formData!['description']}'.trim(),
          unitName: '${formData['unitName']}'.trim(),
          displayName: '${formData['displayName']}'.trim(),
          private: private,
          favorite: favorite,
          aggregationType: formData['aggregationType'] as AggregationType?,
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
            icon: Icons.warning,
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
                    semanticsLabel: 'Measurable - name field',
                    autofocus: widget.isCreateMode,
                  ),
                  SettingsFormTextField(
                    key: const Key('measurable_description_field'),
                    initialValue: item.description,
                    labelText: messages.settingsMeasurableDescriptionLabel,
                    fieldRequired: false,
                    multiline: true,
                    name: 'description',
                    semanticsLabel: 'Measurable - description field',
                  ),
                  SettingsFormTextField(
                    initialValue: item.unitName,
                    labelText: messages.settingsMeasurableUnitLabel,
                    fieldRequired: false,
                    name: 'unitName',
                    semanticsLabel: 'Measurable - unit name field',
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
                        semanticsLabel: 'Measurable - aggregation type field',
                        onTap: () => _pickAggregationType(field),
                      );
                    },
                  ),
                ],
              ),
              SettingsFormSection(
                title: messages.habitSectionOptionsTitle,
                children: [
                  FormSwitch(
                    name: 'favorite',
                    initialValue: item.favorite ?? false,
                    title: messages.favoriteLabel,
                    icon: Icons.star_outline_rounded,
                  ),
                  FormSwitch(
                    name: 'private',
                    initialValue: item.private,
                    title: messages.privateLabel,
                    subtitle: messages.privateSwitchDescription,
                    icon: Icons.lock_outline,
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
