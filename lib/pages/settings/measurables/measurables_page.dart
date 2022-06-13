import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/pages/settings/measurables/measurable_type_card.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
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
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Lato',
        fontSize: 20,
      ),
      physics: const BouncingScrollPhysics(),
      borderRadius: BorderRadius.circular(8.0),
      axisAlignment: isPortrait ? 0.0 : -1.0,
      openAxisAlignment: 0.0,
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
    AppLocalizations localizations = AppLocalizations.of(context)!;

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

        return Scaffold(
          appBar: TitleAppBar(title: localizations.settingsMeasurablesTitle),
          backgroundColor: AppColors.bodyBgColor,
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.entryBgColor,
            onPressed: () {
              pushNamedRoute('/settings/create_measurable');
            },
            child: const Icon(MdiIcons.plus, size: 32),
          ),
          body: Stack(
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
            ],
          ),
        );
      },
    );
  }
}
