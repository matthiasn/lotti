import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/features/settings/ui/pages/form_text_field.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

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
  final GlobalKey<State<StatefulWidget>> _measurableNameKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _measurableDescrKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _measurableUnitAbbrKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _measurablePrivateKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _measurableAggreTypeKey = GlobalKey();
  final GlobalKey<State<StatefulWidget>> _measurableDeleteKey = GlobalKey();

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
          SliverShowCaseTitleBar(
            title: context.messages.settingsMeasurableDetailsLabel,
            pinned: true,
            showcaseIcon: IconButton(
              onPressed: () {
                ShowCaseWidget.of(context).startShowCase(
                  [
                    _measurableNameKey,
                    _measurableDescrKey,
                    _measurableUnitAbbrKey,
                    _measurablePrivateKey,
                    _measurableAggreTypeKey,
                    _measurableDeleteKey,
                  ],
                );
              },
              icon: const Icon(
                Icons.info_outline_rounded,
              ),
            ),
            actions: [
              if (dirty)
                TextButton(
                  key: const Key('measurable_save'),
                  onPressed: onSavePressed,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      context.messages.settingsMeasurableSaveLabel,
                      style: saveButtonStyle(Theme.of(context)),
                      semanticsLabel: 'Save Measurable',
                    ),
                  ),
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
                        ShowcaseWithWidget(
                          startNav: true,
                          showcaseKey: _measurableNameKey,
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsMeasurableShowCaseNameTooltip,
                          ),
                          child: FormTextField(
                            key: const Key('measurable_name_field'),
                            initialValue: item.displayName,
                            labelText:
                                context.messages.settingsMeasurableNameLabel,
                            name: 'displayName',
                            semanticsLabel: 'Measurable - name field',
                            large: true,
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          showcaseKey: _measurableDescrKey,
                          description: ShowcaseTextStyle(
                            descriptionText: context.messages
                                .settingsMeasurableShowCaseDescrTooltip,
                          ),
                          child: FormTextField(
                            key: const Key('measurable_description_field'),
                            initialValue: item.description,
                            labelText: context
                                .messages.settingsMeasurableDescriptionLabel,
                            fieldRequired: false,
                            name: 'description',
                            semanticsLabel: 'Measurable - description field',
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          showcaseKey: _measurableUnitAbbrKey,
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsMeasurableShowCaseUnitTooltip,
                          ),
                          child: FormTextField(
                            initialValue: item.unitName,
                            labelText:
                                context.messages.settingsMeasurableUnitLabel,
                            fieldRequired: false,
                            name: 'unitName',
                            semanticsLabel: 'Measurable - unit name field',
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          showcaseKey: _measurablePrivateKey,
                          description: ShowcaseTextStyle(
                            descriptionText: context.messages
                                .settingsMeasurableShowCasePrivateTooltip,
                          ),
                          child: FormSwitch(
                            name: 'private',
                            initialValue: item.private,
                            title:
                                context.messages.settingsMeasurablePrivateLabel,
                            activeColor: context.colorScheme.error,
                          ),
                        ),
                        inputSpacerSmall,
                        ShowcaseWithWidget(
                          showcaseKey: _measurableAggreTypeKey,
                          description: ShowcaseTextStyle(
                            descriptionText: context.messages
                                .settingsMeasurableShowCaseAggreTypeTooltip,
                          ),
                          child: FormBuilderDropdown(
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
                                    style: context.textTheme.titleMedium,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ShowcaseWithWidget(
                          isTooltipTop: true,
                          endNav: true,
                          showcaseKey: _measurableDeleteKey,
                          description: ShowcaseTextStyle(
                            descriptionText: context
                                .messages.settingsMeasurableShowCaseDelTooltip,
                          ),
                          child: IconButton(
                            icon: Icon(MdiIcons.trashCanOutline),
                            iconSize: settingsIconSize,
                            tooltip: context
                                .messages.settingsMeasurableDeleteTooltip,
                            onPressed: () async {
                              const deleteKey = 'deleteKey';
                              final result = await showModalActionSheet<String>(
                                context: context,
                                title:
                                    context.messages.measurableDeleteQuestion,
                                actions: [
                                  ModalSheetAction(
                                    icon: Icons.warning,
                                    label: context
                                        .messages.measurableDeleteConfirm,
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

        return ShowCaseWidget(
          builder: (context) => MeasurableDetailsPage(
            dataType: dataType,
          ),
        );
      },
    );
  }
}
