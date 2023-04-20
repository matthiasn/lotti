import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/form/form_switch.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MeasurableDetailsPage extends StatefulWidget {
  const MeasurableDetailsPage({
    required this.dataType,
    super.key,
  });

  final MeasurableDataType dataType;

  @override
  State<MeasurableDetailsPage> createState() {
    return _MeasurableDetailsPageState();
  }
}

class _MeasurableDetailsPageState extends State<MeasurableDetailsPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  @override
  Widget build(BuildContext context) {
    void maybePop() => Navigator.of(context).maybePop();
    final localizations = AppLocalizations.of(context)!;
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

        maybePop();
      }
    }

    return Scaffold(
      backgroundColor: styleConfig().negspace,
      appBar: TitleAppBar(
        title: widget.dataType.displayName,
        actions: [
          if (dirty)
            TextButton(
              key: const Key('measurable_save'),
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  localizations.settingsMeasurableSaveLabel,
                  style: saveButtonStyle(),
                  semanticsLabel: 'Save Measurable',
                ),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
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
                      children: <Widget>[
                        FormTextField(
                          key: const Key('measurable_name_field'),
                          initialValue: item.displayName,
                          labelText: localizations.settingsMeasurableNameLabel,
                          name: 'displayName',
                          semanticsLabel: 'Measurable - name field',
                        ),
                        inputSpacer,
                        FormTextField(
                          key: const Key('measurable_description_field'),
                          initialValue: item.description,
                          labelText:
                              localizations.settingsMeasurableDescriptionLabel,
                          fieldRequired: false,
                          name: 'description',
                          semanticsLabel: 'Measurable - description field',
                        ),
                        inputSpacer,
                        FormTextField(
                          initialValue: item.unitName,
                          labelText: localizations.settingsMeasurableUnitLabel,
                          fieldRequired: false,
                          name: 'unitName',
                          semanticsLabel: 'Measurable - unit name field',
                        ),
                        inputSpacer,
                        FormSwitch(
                          name: 'private',
                          initialValue: item.private,
                          title: localizations.settingsMeasurablePrivateLabel,
                          activeColor: styleConfig().private,
                        ),
                        inputSpacer,
                        FormBuilderDropdown(
                          name: 'aggregationType',
                          initialValue: item.aggregationType,
                          decoration: inputDecoration(
                            labelText: localizations
                                .settingsMeasurableAggregationLabel,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.close,
                                color: styleConfig().primaryTextColor,
                              ),
                            ),
                          ),
                          iconEnabledColor: styleConfig().primaryTextColor,
                          style: const TextStyle(fontSize: 40),
                          dropdownColor: styleConfig().cardColor,
                          items: AggregationType.values.map((aggregationType) {
                            return DropdownMenuItem(
                              value: aggregationType,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  EnumToString.convertToString(
                                    aggregationType,
                                  ),
                                  style: TextStyle(
                                    fontSize: fontSizeMedium,
                                    color: styleConfig().primaryTextColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(MdiIcons.trashCanOutline),
                          iconSize: settingsIconSize,
                          tooltip:
                              localizations.settingsMeasurableDeleteTooltip,
                          color: styleConfig().secondaryTextColor,
                          onPressed: () async {
                            const deleteKey = 'deleteKey';
                            final result = await showModalActionSheet<String>(
                              context: context,
                              title: localizations.measurableDeleteQuestion,
                              actions: [
                                SheetAction(
                                  icon: Icons.warning,
                                  label: localizations.measurableDeleteConfirm,
                                  key: deleteKey,
                                  isDestructiveAction: true,
                                  isDefaultAction: true,
                                ),
                              ],
                            );

                            if (result == deleteKey) {
                              await persistenceLogic.upsertEntityDefinition(
                                item.copyWith(deletedAt: DateTime.now()),
                              );

                              maybePop();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder(
      stream: _db.watchMeasurableDataTypeById(measurableId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> snapshot,
      ) {
        final dataType = snapshot.data;

        if (dataType == null) {
          return EmptyScaffoldWithTitle(localizations.measurableNotFound);
        }

        return MeasurableDetailsPage(
          dataType: dataType,
        );
      },
    );
  }
}
