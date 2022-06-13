import 'package:auto_route/auto_route.dart';
import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/settings/form_text_field.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

const double iconSize = 24.0;

class MeasurableDetailsPage extends StatefulWidget {
  const MeasurableDetailsPage({
    Key? key,
    required this.dataType,
  }) : super(key: key);

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
    AppLocalizations localizations = AppLocalizations.of(context)!;
    final MeasurableDataType item = widget.dataType;

    onSavePressed() async {
      _formKey.currentState!.save();
      if (_formKey.currentState!.validate()) {
        final formData = _formKey.currentState?.value;
        debugPrint('$formData');
        MeasurableDataType dataType = item.copyWith(
          description: '${formData!['description']}'.trim(),
          unitName: '${formData['unitName']}'.trim(),
          displayName: '${formData['displayName']}'.trim(),
          private: formData['private'],
          favorite: formData['favorite'],
          aggregationType: formData['aggregationType'],
        );

        persistenceLogic.upsertEntityDefinition(dataType);
        setState(() {
          dirty = false;
        });
        context.router.pop();
      }
    }

    return Scaffold(
      backgroundColor: AppColors.bodyBgColor,
      appBar: TitleAppBar(
        title: localizations.settingsMeasurablesTitle,
        actions: [
          if (dirty)
            TextButton(
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: AppColors.headerBgColor,
                  padding: const EdgeInsets.all(24.0),
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
                              initialValue: item.displayName,
                              labelText: AppLocalizations.of(context)!
                                  .settingsMeasurableNameLabel,
                              name: 'displayName',
                            ),
                            FormTextField(
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
                              clearIcon: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
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
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      EnumToString.convertToString(
                                          aggregationType),
                                      style: TextStyle(
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
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(MdiIcons.trashCanOutline),
                              iconSize: 24,
                              tooltip: AppLocalizations.of(context)!
                                  .settingsMeasurableDeleteTooltip,
                              color: AppColors.appBarFgColor,
                              onPressed: () {
                                persistenceLogic.upsertEntityDefinition(
                                  item.copyWith(
                                    deletedAt: DateTime.now(),
                                  ),
                                );
                                context.router.pop();
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
  final JournalDb _db = getIt<JournalDb>();
  final String measurableId;

  EditMeasurablePage({
    Key? key,
    @PathParam() required this.measurableId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchMeasurableDataTypeById(measurableId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> snapshot,
      ) {
        MeasurableDataType? dataType = snapshot.data;

        if (dataType == null) {
          return const SizedBox.shrink();
        }

        return MeasurableDetailsPage(
          dataType: dataType,
        );
      },
    );
  }
}
