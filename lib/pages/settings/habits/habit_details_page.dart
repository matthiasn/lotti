import 'package:adaptive_dialog/adaptive_dialog.dart';
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
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class HabitDetailsPage extends StatefulWidget {
  const HabitDetailsPage({
    super.key,
    required this.habitDefinition,
  });

  final HabitDefinition habitDefinition;

  @override
  State<HabitDetailsPage> createState() {
    return _HabitDetailsPageState();
  }
}

class _HabitDetailsPageState extends State<HabitDetailsPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = false;

  @override
  Widget build(BuildContext context) {
    void maybePop() => Navigator.of(context).maybePop();
    final localizations = AppLocalizations.of(context)!;
    final item = widget.habitDefinition;

    Future<void> onSavePressed() async {
      _formKey.currentState!.save();
      if (_formKey.currentState!.validate()) {
        final formData = _formKey.currentState?.value;
        final private = formData?['private'] as bool? ?? false;
        final dataType = item.copyWith(
          name: '${formData!['name']}'.trim(),
          description: '${formData['description']}'.trim(),
          private: private,
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
        title: widget.habitDefinition.name,
        actions: [
          if (dirty)
            TextButton(
              key: const Key('habit_save'),
              onPressed: onSavePressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  AppLocalizations.of(context)!.settingsHabitsSaveLabel,
                  style: saveButtonStyle(),
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
                borderRadius: BorderRadius.circular(0),
                child: Container(
                  color: styleConfig().cardColor,
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
                              key: const Key('habit_name_field'),
                              initialValue: item.name,
                              labelText: AppLocalizations.of(context)!
                                  .settingsHabitsNameLabel,
                              name: 'name',
                            ),
                            FormTextField(
                              key: const Key('habit_description_field'),
                              initialValue: item.description,
                              labelText: AppLocalizations.of(context)!
                                  .settingsHabitsDescriptionLabel,
                              fieldRequired: false,
                              name: 'description',
                            ),
                            FormBuilderSwitch(
                              name: 'private',
                              initialValue: item.private,
                              title: Text(
                                AppLocalizations.of(context)!
                                    .settingsHabitsPrivateLabel,
                                style: formLabelStyle(),
                              ),
                              activeColor: styleConfig().private,
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
                                  .settingsHabitsDeleteTooltip,
                              color: styleConfig().cardColor,
                              onPressed: () async {
                                const deleteKey = 'deleteKey';
                                final result =
                                    await showModalActionSheet<String>(
                                  context: context,
                                  title: localizations.habitDeleteQuestion,
                                  actions: [
                                    SheetAction(
                                      icon: Icons.warning,
                                      label: localizations.habitDeleteConfirm,
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
        ),
      ),
    );
  }
}

class EditHabitPage extends StatelessWidget {
  EditHabitPage({
    super.key,
    required this.habitId,
  });

  final JournalDb _db = getIt<JournalDb>();
  final String habitId;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder(
      stream: _db.watchHabitById(habitId),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> snapshot,
      ) {
        final habitDefinition = snapshot.data;

        if (habitDefinition == null) {
          return EmptyScaffoldWithTitle(localizations.habitNotFound);
        }

        return HabitDetailsPage(
          habitDefinition: habitDefinition,
        );
      },
    );
  }
}
