import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
import 'package:lotti/widgets/search/search_widget.dart';
import 'package:showcaseview/showcaseview.dart';


class DefinitionsListPage<T> extends StatefulWidget {
  const DefinitionsListPage({
    required this.stream,
    required this.title,
    required this.getName,
    required this.definitionCard,
    required this.floatingActionButton,
    this.initialSearchTerm,
    this.searchCallback,
    
    super.key,
  });

  final Stream<List<T>> stream;
  final String title;
  final String Function(T) getName;
  final Widget Function(int index, T item) definitionCard;
  final Widget? floatingActionButton;
  final String? initialSearchTerm;
  final void Function(String)? searchCallback;

  @override
  State<DefinitionsListPage<T>> createState() => _DefinitionsListPageState();
}

class _DefinitionsListPageState<T> extends State<DefinitionsListPage<T>> {
  String match = '';


  @override
  void initState() {
    super.initState();

    setState(() {
      if (widget.initialSearchTerm != null) {
        match = '${widget.initialSearchTerm}';
      }
    });

    
  }

  Future<void> onQueryChanged(String query) async {
    setState(() {
      widget.searchCallback?.call(query);
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
          floatingActionButton: widget.floatingActionButton,
          body: CustomScrollView(
            // ignore: require_trailing_commas
            slivers: <Widget>[
              SliverTitleBar(
                widget.title,
                pinned: true,
                showBackButton: true,
              ),
              SliverToBoxAdapter(
                child: SearchWidget(
                  text: match,
                  onChanged: onQueryChanged,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Column(
                    children: List.generate(
                      filtered.length,
                      (int index) {
                        return widget.definitionCard(
                          index,
                          filtered.elementAt(index),
                        );
                      },
                    ),
                  ),
                ),
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
    required this.createFn,
    required this.showcaseKey, 
    this.semanticLabel,
    super.key,
  });

  final void Function() createFn;
  final String? semanticLabel;
  final GlobalKey showcaseKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Showcase(
        title: 'Create a new entry!',
         titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        descTextStyle: const TextStyle(fontSize: 14, color: Colors.white),
        titleAlignment: Alignment.topCenter,
        tooltipPosition: TooltipPosition.top,
        key: showcaseKey,
        description: 'Tap here to create a new entry!',
        child: FloatingActionButton(
          onPressed: createFn,
          child: Icon(
            Icons.add_rounded,
            semanticLabel: semanticLabel,
          ),
        ),
      ),
    );
  }
}
