import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:lotti/blocs/settings/categories/category_settings_cubit.dart';
import 'package:lotti/blocs/settings/categories/category_settings_state.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/select_color_field.dart';
import 'package:lotti/features/settings/ui/widgets/entity_detail_card.dart';
import 'package:lotti/features/settings/ui/widgets/form/form_switch.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class CategoryDetailsPage extends StatefulWidget {
  const CategoryDetailsPage({super.key});

  @override
  State<CategoryDetailsPage> createState() => _CategoryDetailsPageState();
}

class _CategoryDetailsPageState extends State<CategoryDetailsPage> {
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
              body: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(
                    title: Text(
                      context.messages.settingsCategoriesDetailsLabel,
                      style: appBarTextStyleNewLarge.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    pinned: true,
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
                  SliverToBoxAdapter(
                    child: EntityDetailCard(
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
                                  key: const Key(
                                    'category_name_field',
                                  ),
                                  name: 'name',
                                  initialValue: item.name,
                                  textCapitalization:
                                      TextCapitalization.sentences,
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
                                inputSpacer,
                                FormSwitch(
                                  name: 'private',
                                  initialValue: item.private,
                                  title: context
                                      .messages.settingsHabitsPrivateLabel,
                                  activeColor: context.colorScheme.error,
                                ),
                                FormSwitch(
                                  name: 'active',
                                  key: const Key(
                                    'category_active',
                                  ),
                                  initialValue: state.categoryDefinition.active,
                                  title: context.messages.dashboardActiveLabel,
                                  activeColor: starredGold,
                                ),
                                FormSwitch(
                                  name: 'favorite',
                                  key: const Key(
                                    'category_favorite',
                                  ),
                                  initialValue:
                                      state.categoryDefinition.favorite,
                                  title: context
                                      .messages.settingsMeasurableFavoriteLabel,
                                  activeColor: starredGold,
                                ),
                                inputSpacer,
                                SelectColorField(
                                  hexColor: state.categoryDefinition.color,
                                  onColorChanged: cubit.setColor,
                                ),
                                inputSpacer,
                              ],
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                key: const Key('category_delete'),
                                icon: Icon(MdiIcons.trashCanOutline),
                                iconSize: settingsIconSize,
                                tooltip: context
                                    .messages.settingsHabitsDeleteTooltip,
                                color: context.colorScheme.outline,
                                onPressed: () async {
                                  const deleteKey = 'deleteKey';
                                  final result =
                                      await showModalActionSheet<String>(
                                    context: context,
                                    title:
                                        context.messages.categoryDeleteQuestion,
                                    actions: [
                                      ModalSheetAction(
                                        icon: Icons.warning,
                                        label: context
                                            .messages.categoryDeleteConfirm,
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
                        ],
                      ),
                    ),
                  ),
                ],
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
