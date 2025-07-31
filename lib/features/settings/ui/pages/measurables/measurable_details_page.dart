import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/settings/ui/pages/form_text_field.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
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
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(
              context.messages.settingsMeasurableDetailsLabel,
              style: appBarTextStyleNewLarge.copyWith(
                color: Theme.of(context).primaryColor,
              ),
            ),
            pinned: true,
            actions: [
              if (dirty)
                LottiTertiaryButton(
                  key: const Key('measurable_save'),
                  label: context.messages.settingsMeasurableSaveLabel,
                  onPressed: onSavePressed,
                ),
            ],
          ),
          SliverToBoxAdapter(
            child: EntityDetailCard(
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
                          labelText:
                              context.messages.settingsMeasurableNameLabel,
                          name: 'displayName',
                          semanticsLabel: 'Measurable - name field',
                          large: true,
                        ),
                        inputSpacerSmall,
                        FormTextField(
                          key: const Key('measurable_description_field'),
                          initialValue: item.description,
                          labelText: context
                              .messages.settingsMeasurableDescriptionLabel,
                          fieldRequired: false,
                          name: 'description',
                          semanticsLabel: 'Measurable - description field',
                        ),
                        inputSpacerSmall,
                        FormTextField(
                          initialValue: item.unitName,
                          labelText:
                              context.messages.settingsMeasurableUnitLabel,
                          fieldRequired: false,
                          name: 'unitName',
                          semanticsLabel: 'Measurable - unit name field',
                        ),
                        inputSpacerSmall,
                        FormSwitch(
                          name: 'private',
                          initialValue: item.private,
                          title:
                              context.messages.settingsMeasurablePrivateLabel,
                          activeColor: context.colorScheme.error,
                        ),
                        inputSpacerSmall,
                        FormBuilderDropdown(
                          name: 'aggregationType',
                          initialValue: item.aggregationType,
                          decoration: inputDecoration(
                            labelText: context
                                .messages.settingsMeasurableAggregationLabel,
                            suffixIcon: const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.close_rounded),
                            ),
                            themeData: Theme.of(context),
                          ),
                          style: TextStyle(
                            fontSize: 40,
                            color: context.textTheme.titleLarge?.color,
                          ),
                          items: AggregationType.values.map((aggregationType) {
                            return DropdownMenuItem(
                              value: aggregationType,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text(
                                  EnumToString.convertToString(
                                    aggregationType,
                                  ),
                                  style: context.textTheme.titleMedium,
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
                          icon: Icon(MdiIcons.trashCanOutline),
                          iconSize: settingsIconSize,
                          tooltip:
                              context.messages.settingsMeasurableDeleteTooltip,
                          onPressed: () async {
                            const deleteKey = 'deleteKey';
                            final result = await showModalActionSheet<String>(
                              context: context,
                              title: context.messages.measurableDeleteQuestion,
                              actions: [
                                ModalSheetAction(
                                  icon: Icons.warning,
                                  label:
                                      context.messages.measurableDeleteConfirm,
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
        ],
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
    return StreamBuilder(
      stream: _db.watchMeasurableDataTypeById(measurableId),
      builder: (
        BuildContext context,
        AsyncSnapshot<MeasurableDataType?> snapshot,
      ) {
        final dataType = snapshot.data;

        if (dataType == null) {
          return EmptyScaffoldWithTitle(context.messages.measurableNotFound);
        }

        return MeasurableDetailsPage(
          dataType: dataType,
        );
      },
    );
  }
}
