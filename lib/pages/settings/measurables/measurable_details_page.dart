import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:auto_route/auto_route.dart';
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
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class MeasurableDetailsPage extends StatefulWidget {
  const MeasurableDetailsPage({
    super.key,
    required this.dataType,
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

        await getIt<AppRouter>().pop();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(
        title: localizations.settingsMeasurablesTitle,
        actions: [
          if (dirty)
            TextButton(
              key: const Key('measurable_save'),
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  AppLocalizations.of(context)!.settingsMeasurableSaveLabel,
                  style: saveButtonStyle,
                ),
              ),
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppColors.headerBgColor,
                  padding: const EdgeInsets.all(24),
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
                              labelText: AppLocalizations.of(context)!
                                  .settingsMeasurableNameLabel,
                              name: 'displayName',
                            ),
                            FormTextField(
                              key: const Key('measurable_description_field'),
                              initialValue: item.description,
                              labelText: AppLocalizations.of(context)!
                                  .settingsMeasurableDescriptionLabel,
                              fieldRequired: false,
                              name: 'description',
                            ),
                            FormTextField(
                              initialValue: item.unitName,
                              labelText: AppLocalizations.of(context)!
                                  .settingsMeasurableUnitLabel,
                              fieldRequired: false,
                              name: 'unitName',
                            ),
                            FormBuilderSwitch(
                              name: 'private',
                              initialValue: item.private,
                              title: Text(
                                AppLocalizations.of(context)!
                                    .settingsMeasurablePrivateLabel,
                                style: formLabelStyle,
                              ),
                              activeColor: AppColors.private,
                            ),
                            FormBuilderSwitch(
                              name: 'favorite',
                              initialValue: item.favorite,
                              title: Text(
                                AppLocalizations.of(context)!
                                    .settingsMeasurableFavoriteLabel,
                                style: formLabelStyle,
                              ),
                              activeColor: AppColors.starredGold,
                            ),
                            FormBuilderDropdown(
                              name: 'aggregationType',
                              initialValue: item.aggregationType,
                              decoration: InputDecoration(
                                labelText: AppLocalizations.of(context)!
                                    .settingsMeasurableAggregationLabel,
                                labelStyle: formLabelStyle,
                              ),
                              iconEnabledColor: AppColors.entryTextColor,
                              clearIcon: const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.close,
                                  color: AppColors.entryTextColor,
                                ),
                              ),
                              style: const TextStyle(fontSize: 40),
                              allowClear: true,
                              dropdownColor: AppColors.headerBgColor,
                              items:
                                  AggregationType.values.map((aggregationType) {
                                return DropdownMenuItem(
                                  value: aggregationType,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Text(
                                      EnumToString.convertToString(
                                        aggregationType,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.entryTextColor,
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
                              tooltip: AppLocalizations.of(context)!
                                  .settingsMeasurableDeleteTooltip,
                              color: AppColors.appBarFgColor,
                              onPressed: () async {
                                const deleteKey = 'deleteKey';
                                final result =
                                    await showModalActionSheet<String>(
                                  context: context,
                                  title: localizations.measurableDeleteQuestion,
                                  actions: [
                                    SheetAction(
                                      icon: Icons.warning,
                                      label:
                                          localizations.measurableDeleteConfirm,
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

                                  await getIt<AppRouter>().pop();
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
            ],
          ),
        ),
      ),
    );
  }
}

class EditMeasurablePage extends StatelessWidget {
  EditMeasurablePage({
    super.key,
    @PathParam() required this.measurableId,
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
