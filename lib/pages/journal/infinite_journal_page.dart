import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:lotti/blocs/journal/journal_page_cubit.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';
import 'package:lotti/widgets/create/add_actions.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

class JournalPageWrapper extends StatelessWidget {
  const JournalPageWrapper({
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (RouteSettings settings) {
        return MaterialPageRoute(
          settings: settings,
          builder: (BuildContext context) {
            return BlocProvider<JournalPageCubit>(
              create: (BuildContext context) => JournalPageCubit(),
              child: const InfiniteJournalPage(),
            );
          },
        );
      },
    );
  }
}

class InfiniteJournalPage extends StatefulWidget {
  const InfiniteJournalPage({
    super.key,
    this.navigatorKey,
  });

  final GlobalKey? navigatorKey;

  @override
  State<InfiniteJournalPage> createState() => _InfiniteJournalPageState();
}

class _InfiniteJournalPageState extends State<InfiniteJournalPage> {
  final JournalDb _db = getIt<JournalDb>();

  StreamController<List<TagEntity>> matchingTagsController =
      StreamController<List<TagEntity>>();

  Set<String> tagIds = {};
  static const _pageSize = 50;

  final PagingController<int, JournalEntity> _pagingController =
      PagingController(firstPageKey: 0);

  @override
  void initState() {
    _pagingController.addPageRequestListener(_fetchPage);
    super.initState();
  }

  // TODO: move all this to the new JournalPageCubit
  Future<void> _fetchPage(int pageKey) async {
    final cubit = context.read<JournalPageCubit>();

    try {
      Set<String>? entryIds;
      // TODO: rethink tags
      for (final tagId in tagIds) {
        final entryIdsForTag = (await _db.entryIdsByTagId(tagId)).toSet();
        if (entryIds == null) {
          entryIds = entryIdsForTag;
        } else {
          entryIds = entryIds.intersection(entryIdsForTag);
        }
      }

      final types = cubit.state.selectedEntryTypes
          .map((e) => e?.typeName)
          .whereType<String>()
          .toList();

      final fullTextMatches = cubit.state.fullTextMatches.toList();
      final ids = fullTextMatches.isNotEmpty ? fullTextMatches : null;

      final newItems = await _db
          .watchJournalEntities(
            types: types,
            // TODO: bring back tags matching
            // ids: entryIds?.toList(),
            ids: ids,
            starredStatuses:
                cubit.state.starredEntriesOnly ? [true] : [true, false],
            privateStatuses:
                cubit.state.privateEntriesOnly ? [true] : [true, false],
            flaggedStatuses: cubit.state.flaggedEntriesOnly ? [1] : [1, 0],
            limit: _pageSize,
            offset: pageKey,
          )
          .first;

      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  Future<void> resetQuery() async {
    _pagingController.refresh();
  }

  void addTag(String tagId) {
    setState(() {
      tagIds.add(tagId);
      resetQuery();
    });
  }

  void removeTag(String remove) {
    setState(() {
      tagIds.remove(remove);
      resetQuery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: styleConfig().negspace,
      floatingActionButton: RadialAddActionButtons(
        radius: isMobile ? 180 : 120,
        isMacOS: isMacOS,
        isIOS: isIOS,
        isAndroid: isAndroid,
      ),
      body: RefreshIndicator(
        onRefresh: () => Future.sync(_pagingController.refresh),
        child: CustomScrollView(
          slivers: <Widget>[
            JournalSliverAppBar(
              resetQuery: resetQuery,
            ),
            PagedSliverList<int, JournalEntity>(
              pagingController: _pagingController,
              builderDelegate: PagedChildBuilderDelegate<JournalEntity>(
                itemBuilder: (context, item, index) {
                  return item.maybeMap(
                    journalImage: (JournalImage image) {
                      return JournalImageCard(
                        item: image,
                        key: ValueKey(item.meta.id),
                      );
                    },
                    orElse: () {
                      return JournalCard(
                        item: item,
                        key: ValueKey(item.meta.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pagingController.dispose();
    super.dispose();
  }
}
