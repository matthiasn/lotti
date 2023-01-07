import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intersperse/intersperse.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/definitions_list_app_bar.dart';
import 'package:lotti/widgets/settings/settings_card.dart';

const double iconSize = 24;

class DefinitionsListPage<T> extends StatefulWidget {
  const DefinitionsListPage({
    super.key,
    required this.stream,
    required this.title,
    required this.getName,
    required this.definitionCard,
    required this.floatingActionButton,
  });

  final Stream<List<T>> stream;
  final String title;
  final String Function(T) getName;
  final Widget Function(int index, T item) definitionCard;
  final Widget? floatingActionButton;

  @override
  State<DefinitionsListPage<T>> createState() => _DefinitionsListPageState();
}

class _DefinitionsListPageState<T> extends State<DefinitionsListPage<T>> {
  String match = '';

  @override
  void initState() {
    super.initState();
  }

  Future<void> onQueryChanged(String query) async {
    setState(() {
      match = query.toLowerCase();
    });
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
          appBar: DefinitionsListAppBar(
            title: widget.title,
            onQueryChanged: onQueryChanged,
            match: match,
          ),
          backgroundColor: styleConfig().negspace,
          floatingActionButton: widget.floatingActionButton,
          body: Stack(
            children: [
              ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                  bottom: 8,
                  top: 8,
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
