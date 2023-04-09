import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/settings/categories/category_settings_cubit.dart';
import 'package:lotti/blocs/settings/categories/category_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/form/form_switch.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CategoryDetailsPage extends StatelessWidget {
  const CategoryDetailsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

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

            final pickerColor = colorFromCssHex(state.categoryDefinition.color);

            return Scaffold(
              backgroundColor: styleConfig().negspace,
              appBar: TitleAppBar(
                title: state.categoryDefinition.name,
                actions: [
                  if (state.dirty && state.valid)
                    TextButton(
                      key: const Key('habit_save'),
                      onPressed: cubit.onSavePressed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          AppLocalizations.of(context)!.settingsHabitsSaveLabel,
                          style: saveButtonStyle(),
                          semanticsLabel: 'Save Category',
                        ),
                      ),
                    )
                ],
              ),
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          FormBuilder(
                            key: state.formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: cubit.setDirty,
                            child: Column(
                              children: <Widget>[
                                FormBuilderTextField(
                                  key: const Key('category_name_field'),
                                  name: 'name',
                                  initialValue: item.name,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  keyboardAppearance: keyboardAppearance(),
                                  validator: FormBuilderValidators.compose([
                                    FormBuilderValidators.required(),
                                    (categoryName) {
                                      final existingId = categoryNames[
                                          categoryName?.toLowerCase()];
                                      if (existingId != null &&
                                          existingId != item.id) {
                                        return localizations
                                            .settingsCategoriesDuplicateError;
                                      }
                                      return null;
                                    }
                                  ]),
                                  style: labelStyle(),
                                  decoration: inputDecoration(
                                    labelText: AppLocalizations.of(context)!
                                        .settingsCategoriesNameLabel,
                                    semanticsLabel: 'Category name field',
                                  ),
                                ),
                                inputSpacer,
                                FormSwitch(
                                  name: 'private',
                                  initialValue: item.private,
                                  title:
                                      localizations.settingsHabitsPrivateLabel,
                                  activeColor: styleConfig().private,
                                ),
                                FormSwitch(
                                  name: 'active',
                                  key: const Key('category_active'),
                                  initialValue: state.categoryDefinition.active,
                                  title: localizations.dashboardActiveLabel,
                                  activeColor: styleConfig().starredGold,
                                ),
                                ColorPicker(
                                  pickerColor: pickerColor,
                                  enableAlpha: false,
                                  labelTypes: const [],
                                  onColorChanged: cubit.setColor,
                                )
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
                                      .settingsHabitsDeleteTooltip,
                                  color: styleConfig().secondaryTextColor,
                                  onPressed: () async {
                                    const deleteKey = 'deleteKey';
                                    final result =
                                        await showModalActionSheet<String>(
                                      context: context,
                                      title:
                                          localizations.categoryDeleteQuestion,
                                      actions: [
                                        SheetAction(
                                          icon: Icons.warning,
                                          label: localizations
                                              .categoryDeleteConfirm,
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
                          ),
                          // const HabitAutocompleteWrapper(),
                        ],
                      ),
                    ),
                  ),
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

        return BlocProvider<CategorySettingsCubit>(
          create: (_) => CategorySettingsCubit(
            categoryDefinition,
            context: context,
          ),
          child: const CategoryDetailsPage(),
        );
      },
    );
  }
}
