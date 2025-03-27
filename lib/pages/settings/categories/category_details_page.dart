import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/settings/categories/category_settings_cubit.dart';
import 'package:lotti/blocs/settings/categories/category_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/select_color_field.dart';
import 'package:lotti/features/manual/widget/showcase_text_style.dart';
import 'package:lotti/features/manual/widget/showcase_with_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:lotti/widgets/settings/entity_detail_card.dart';
import 'package:lotti/widgets/settings/form/form_switch.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:showcaseview/showcaseview.dart';

class CategoryDetailsPage extends StatefulWidget {
  const CategoryDetailsPage({super.key});

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
  final _categoryNameKey = GlobalKey();
  final _categoryPrivateFlagKey = GlobalKey();
  final _categoryActiveFlagKey = GlobalKey();
  final _categoryFavoriteFlagKey = GlobalKey();
  final _categoryColorPickerKey = GlobalKey();
  final _categoryDeleteKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryDefinition>>(
      stream: getIt<JournalDb>().watchCategories(),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[];
        final categoryNames = <String, String>{};

        for (final category in categories) {
          categoryNames[category.name.toLowerCase()] = category.id;
        }

        return BlocBuilder<CategorySettingsCubit, CategorySettingsState>(
          builder: (context, CategorySettingsState state) {
            final item = state.categoryDefinition;
            final cubit = context.read<CategorySettingsCubit>();

            return Scaffold(
              appBar: TitleWidgetAppBar(
                title: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 70),
                  child: IconButton(
                    onPressed: () {
                      ShowCaseWidget.of(context).startShowCase(
                        [
                          _categoryNameKey,
                          _categoryPrivateFlagKey,
                          _categoryActiveFlagKey,
                          _categoryFavoriteFlagKey,
                          _categoryColorPickerKey,
                          _categoryDeleteKey,
                        ],
                      );
                    },
                    icon: const Icon(
                      Icons.info_outline_rounded,
                    ),
                  ),
                ),
                actions: [
                  if (state.dirty && state.valid)
                    TextButton(
                      key: const Key(
                        'category_save',
                      ),
                      onPressed: cubit.onSavePressed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        child: Text(
                          context.messages.settingsHabitsSaveLabel,
                          style: saveButtonStyle(
                            Theme.of(
                              context,
                            ),
                          ),
                          semanticsLabel: 'Save Category',
                        ),
                      ),
                    ),
                ],
              ),
              body: EntityDetailCard(
                child: Column(
                  children: [
                    FormBuilder(
                      key: state.formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: cubit.setDirty,
                      child: Column(
                        children: <Widget>[
                          ShowcaseWithWidget(
                            showcaseKey: _categoryNameKey,
                            description: ShowcaseTextStyle(
                              descriptionText: context
                                  .messages.settingsCategoryShowCaseNameTooltip,
                            ),
                            child: FormBuilderTextField(
                              key: const Key(
                                'category_name_field',
                              ),
                              name: 'name',
                              initialValue: item.name,
                              textCapitalization: TextCapitalization.sentences,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontSize: fontSizeLarge,
                                  ),
                              validator: FormBuilderValidators.compose([
                                FormBuilderValidators.required(),
                                (categoryName) {
                                  final existingId = categoryNames[
                                      categoryName?.toLowerCase()];
                                  if (existingId != null &&
                                      existingId != item.id) {
                                    return context.messages
                                        .settingsCategoriesDuplicateError;
                                  }
                                  return null;
                                }
                              ]),
                              decoration: inputDecoration(
                                labelText: context
                                    .messages.settingsCategoriesNameLabel,
                                semanticsLabel: 'Category name field',
                                themeData: Theme.of(
                                  context,
                                ),
                              ),
                            ),
                          ),
                          inputSpacer,
                          ShowcaseWithWidget(
                            showcaseKey: _categoryPrivateFlagKey,
                            description: ShowcaseTextStyle(
                              descriptionText: context.messages
                                  .settingsCategoryShowCasePrivateTooltip,
                            ),
                            child: FormSwitch(
                              name: 'private',
                              initialValue: item.private,
                              title:
                                  context.messages.settingsHabitsPrivateLabel,
                              activeColor: context.colorScheme.error,
                            ),
                          ),
                          ShowcaseWithWidget(
                            showcaseKey: _categoryActiveFlagKey,
                            description: ShowcaseTextStyle(
                              descriptionText: context.messages
                                  .settingsCategoryShowCaseActiveTooltip,
                            ),
                            child: FormSwitch(
                              name: 'active',
                              key: const Key(
                                'category_active',
                              ),
                              initialValue: state.categoryDefinition.active,
                              title: context.messages.dashboardActiveLabel,
                              activeColor: starredGold,
                            ),
                          ),
                          ShowcaseWithWidget(
                            showcaseKey: _categoryFavoriteFlagKey,
                            description: ShowcaseTextStyle(
                              descriptionText: context
                                  .messages.settingsCategoryShowCaseFavTooltip,
                            ),
                            child: FormSwitch(
                              name: 'favorite',
                              key: const Key(
                                'category_favorite',
                              ),
                              initialValue: state.categoryDefinition.favorite,
                              title: context
                                  .messages.settingsMeasurableFavoriteLabel,
                              activeColor: starredGold,
                            ),
                          ),
                          inputSpacer,
                          ShowcaseWithWidget(
                            showcaseKey: _categoryColorPickerKey,
                            description: ShowcaseTextStyle(
                              descriptionText: context.messages
                                  .settingsCategoryShowCaseColorTooltip,
                            ),
                            child: SelectColorField(
                              hexColor: state.categoryDefinition.color,
                              onColorChanged: cubit.setColor,
                            ),
                          ),
                          inputSpacer,
                        ],
                      ),
                    ),

                    ShowcaseWithWidget(
                      isTooltipTop: true,
                      endNav: true,
                      showcaseKey: _categoryDeleteKey,
                      description: ShowcaseTextStyle(
                        descriptionText:
                            context.messages.settingsCategoryShowCaseDelTooltip,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            key: const Key(
                              'category_delete',
                            ),
                            icon: Icon(
                              MdiIcons.trashCanOutline,
                            ),
                            iconSize: settingsIconSize,
                            tooltip:
                                context.messages.settingsHabitsDeleteTooltip,
                            color: context.colorScheme.outline,
                            onPressed: () async {
                              const deleteKey = 'deleteKey';
                              final result = await showModalActionSheet<String>(
                                context: context,
                                title: context.messages.categoryDeleteQuestion,
                                actions: [
                                  ModalSheetAction(
                                    icon: Icons.warning,
                                    label:
                                        context.messages.categoryDeleteConfirm,
                                    key: deleteKey,
                                    isDestructiveAction: true,
                                    isDefaultAction: true,
                                  ),
                                ],
                              );

                              if (result == deleteKey) {
                                await cubit.delete();
                              }
                            },
                          ),
                        ],
                      ),
                    ), // const HabitAutocompleteWrapper(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class EditCategoryPage extends StatelessWidget {
  EditCategoryPage({
    required this.categoryId,
    super.key,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String categoryId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _db.watchCategoryById(categoryId),
      builder: (
        BuildContext context,
        AsyncSnapshot<CategoryDefinition?> snapshot,
      ) {
        final categoryDefinition = snapshot.data;

        if (categoryDefinition == null) {
          return const EmptyScaffoldWithTitle('');
        }

        return ShowCaseWidget(
          builder: (context) => BlocProvider<CategorySettingsCubit>(
            create: (_) => CategorySettingsCubit(
              categoryDefinition,
              context: context,
            ),
            child: const CategoryDetailsPage(),
          ),
        );
      },
    );
  }
}
