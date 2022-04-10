import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/measurables/measurable_type_card.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

const double iconSize = 24.0;

class MeasurablesPage extends StatefulWidget {
  const MeasurablesPage({Key? key}) : super(key: key);

  @override
  State<MeasurablesPage> createState() => _MeasurablesPageState();
}

class _MeasurablesPageState extends State<MeasurablesPage> {
  final JournalDb _db = getIt<JournalDb>();
  String match = '';

  late final Stream<List<MeasurableDataType>> stream =
      _db.watchMeasurableDataTypes();

  @override
  void initState() {
    super.initState();
    createDefaults();
  }

  void createDefaults() async {
    DateTime now = DateTime.now();

    _db.upsertMeasurableDataType(MeasurableDataType(
      id: '9e9e7a62-1e56-4059-a568-12234db7399b',
      createdAt: now,
      updatedAt: now,
      displayName: 'Water',
      description: 'Volume of water consumed, in milliliters',
      unitName: 'ml',
      version: 0,
      vectorClock: null,
    ));

    _db.upsertMeasurableDataType(MeasurableDataType(
      id: 'f2518f33-af1d-4dbe-ae9b-6a05def5d8f9',
      createdAt: now,
      updatedAt: now,
      displayName: 'Caffeine',
      description: 'Amount of caffeine consumed, in milligrams',
      unitName: 'mg',
      version: 0,
      vectorClock: null,
    ));
  }

  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    double portraitWidth = MediaQuery.of(context).size.width * 0.5;

    return FloatingSearchBar(
      clearQueryOnClose: false,
      automaticallyImplyBackButton: false,
      hint: AppLocalizations.of(context)!.settingsMeasurablesSearchHint,
      scrollPadding: const EdgeInsets.only(top: 16, bottom: 56),
      transitionDuration: const Duration(milliseconds: 800),
      transitionCurve: Curves.easeInOut,
      backgroundColor: AppColors.appBarFgColor,
      margins: const EdgeInsets.only(top: 8),
      queryStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
        fontWeight: FontWeight.w300,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
        fontWeight: FontWeight.w300,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8.0),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
      width: isPortrait ? portraitWidth : 400,
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
    return StreamBuilder<List<MeasurableDataType>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<MeasurableDataType>> snapshot,
      ) {
        List<MeasurableDataType> items = snapshot.data ?? [];
        List<MeasurableDataType> filtered = items
            .where((MeasurableDataType dataType) =>
                dataType.displayName.toLowerCase().contains(match))
            .toList();

        return Stack(
          children: [
            ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: 8,
                top: 64,
              ),
              children: List.generate(
                filtered.length,
                (int index) {
                  return MeasurableTypeCard(
                    item: filtered.elementAt(index),
                    index: index,
                  );
                },
              ),
            ),
            buildFloatingSearchBar(),
            Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: FloatingActionButton(
                  child: const Icon(MdiIcons.plus, size: 32),
                  backgroundColor: AppColors.entryBgColor,
                  onPressed: () {
                    context.router.push(const CreateMeasurableRoute());
                  },
                ),
              ),
            )
          ],
        );
      },
    );
  }
}
