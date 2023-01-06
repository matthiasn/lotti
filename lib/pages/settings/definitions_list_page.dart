import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/settings/settings_card.dart';
import 'package:material_floating_search_bar/material_floating_search_bar.dart';

const double iconSize = 24;

class DefinitionsListPage<T> extends StatefulWidget {
  const DefinitionsListPage({
    super.key,
    required this.stream,
    required this.createFn,
    required this.title,
    required this.getName,
    required this.definitionCard,
  });

  final Stream<List<T>> stream;
  final void Function() createFn;
  final String title;
  final String Function(T) getName;
  final Widget Function(int index, T item) definitionCard;

  @override
  State<DefinitionsListPage<T>> createState() => _DefinitionsListPageState();
}

class _DefinitionsListPageState<T> extends State<DefinitionsListPage<T>> {
  String match = '';

  @override
  void initState() {
    super.initState();
  }

  Widget buildFloatingSearchBar() {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final portraitWidth = MediaQuery.of(context).size.width * 0.5;

    return Theme(
      data: ThemeData(
        brightness: styleConfig().keyboardAppearance,
      ),
      child: FloatingSearchBar(
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
        hintStyle: TextStyle(
          fontFamily: mainFont,
          fontSize: 20,
          color: styleConfig().secondaryTextColor,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<T>>(
      stream: widget.stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<T>> snapshot,
      ) {
        final items = snapshot.data ?? [];
        final filtered = items
            .where(
              (T item) => widget.getName(item).toLowerCase().contains(match),
            )
            .sortedBy(widget.getName)
            .toList();

        return Scaffold(
          appBar: TitleAppBar(title: widget.title),
          backgroundColor: styleConfig().negspace,
          floatingActionButton: FloatingActionButton(
            backgroundColor: styleConfig().primaryColor,
            onPressed: widget.createFn,
            child: SvgPicture.asset(
              styleConfig().actionAddIcon,
              width: 25,
            ),
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
                      return widget.definitionCard(
                        index,
                        filtered.elementAt(index),
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

class FloatingAddIcon extends StatelessWidget {
  const FloatingAddIcon({
    super.key,
    required this.createFn,
  });

  final void Function() createFn;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: styleConfig().primaryColor,
      onPressed: createFn,
      child: SvgPicture.asset(
        styleConfig().actionAddIcon,
        width: 25,
      ),
    );
  }
}
