import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/habits/habits_type_card.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

const double iconSize = 24;

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  String match = '';

  @override
  void initState() {
    super.initState();
  }

  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final portraitWidth = MediaQuery.of(context).size.width * 0.5;

    return FloatingSearchBar(
      clearQueryOnClose: false,
      automaticallyImplyBackButton: false,
      hint: AppLocalizations.of(context)!.settingsMeasurablesSearchHint,
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: styleConfig().cardColor,
      margins: const EdgeInsets.only(top: 8),
      queryStyle: const TextStyle(
        fontFamily: mainFont,
        fontSize: 20,
      ),
      hintStyle: const TextStyle(
        fontFamily: mainFont,
        fontSize: 20,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8),
      axisAlignment: isPortrait ? 0 : -1,
      openAxisAlignment: 0,
      width: isPortrait ? portraitWidth : MediaQuery.of(context).size.width,
      onQueryChanged: (query) async {
        setState(() {
          match = query.toLowerCase();
        });
      },
      actions: [
        FloatingSearchBarAction.searchToClear(
          showIfClosed: false,
        ),
      ],
      builder: (context, transition) {
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    void createHabit() => beamToNamed('/settings/habits/create');

    return StreamBuilder<List<HabitDefinition>>(
      stream: getIt<JournalDb>().watchHabitDefinitions(),
      builder: (
        BuildContext context,
        AsyncSnapshot<List<HabitDefinition>> snapshot,
      ) {
        final items = snapshot.data ?? [];
        final filtered = items
            .where(
              (HabitDefinition habitDefinition) =>
                  habitDefinition.name.toLowerCase().contains(match),
            )
            .sortedBy((item) => item.name)
            .toList();

        return Scaffold(
          appBar: TitleAppBar(title: localizations.settingsHabitsTitle),
          backgroundColor: styleConfig().negspace,
          floatingActionButton: FloatingActionButton(
            backgroundColor: styleConfig().primaryColor,
            onPressed: createHabit,
            child: SvgPicture.asset(styleConfig().actionAddIcon, width: 25),
          ),
          body: Stack(
            children: [
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  bottom: 8,
                  top: 64,
                ),
                children: intersperse(
                  const SettingsDivider(),
                  List.generate(
                    filtered.length,
                    (int index) {
                      return HabitsTypeCard(
                        item: filtered.elementAt(index),
                        index: index,
                      );
                    },
                  ),
                ).toList(),
              ),
              buildFloatingSearchBar(),
            ],
          ),
        );
      },
    );
  }
}
