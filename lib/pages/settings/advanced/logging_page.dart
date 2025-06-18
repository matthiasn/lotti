import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:extended_sliver/extended_sliver.dart';

class LoggingPage extends StatefulWidget {
  const LoggingPage({super.key});

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  bool _isVisible = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChange() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
    });
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      onVisibilityChanged: (info) {
        final isVisible = info.visibleBounds.size.width > 0;
        if (_isVisible != isVisible && mounted) {
          setState(() {
            _isVisible = isVisible;
          });
        }
      },
      key: const Key('logging_page'),
      child: _isVisible
          ? StreamBuilder<List<LogEntry>>(
              stream: getIt<LoggingDb>().watchLogEntries(),
              builder: (
                BuildContext context,
                AsyncSnapshot<List<LogEntry>> snapshot,
              ) {
                final logEntries = snapshot.data ?? [];
                final filteredLogs = logEntries
                    .where((log) =>
                        log.message.toLowerCase().contains(_searchQuery) ||
                        log.domain.toLowerCase().contains(_searchQuery) ||
                        (log.subDomain != null &&
                            log.subDomain!
                                .toLowerCase()
                                .contains(_searchQuery)))
                    .toList();

                return Scaffold(
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.light
                          ? context.colorScheme.surfaceContainerLowest
                          : context.colorScheme.scrim,
                  body: CustomScrollView(
                    slivers: <Widget>[
                      SliverAppBar(
                        expandedHeight: 100,
                        pinned: true,
                        backgroundColor: context.colorScheme.surface,
                        surfaceTintColor: Colors.transparent,
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: context.colorScheme.onSurface,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        flexibleSpace: FlexibleSpaceBar(
                          title: Text(
                            context.messages.settingsLogsTitle,
                            style: TextStyle(
                              color: context.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverPinnedToBoxAdapter(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.colorScheme.surface,
                            border: Border(
                              bottom: BorderSide(
                                color: context.colorScheme.primaryContainer
                                    .withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? context
                                        .colorScheme.surfaceContainerHighest
                                    : null,
                                gradient: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? null
                                    : LinearGradient(
                                        colors: [
                                          context.colorScheme.surfaceContainer,
                                          context
                                              .colorScheme.surfaceContainerHigh
                                              .withValues(alpha: 0.8),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? context.colorScheme.outline
                                          .withValues(alpha: 0.2)
                                      : context.colorScheme.primaryContainer
                                          .withValues(alpha: 0.2),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: context.colorScheme.shadow
                                        .withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search logs...',
                                  hintStyle: TextStyle(
                                    color: context.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.3,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: context.colorScheme.primary
                                        .withValues(alpha: 0.8),
                                    size: 22,
                                    semanticLabel: 'Search icon',
                                  ),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? Material(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: InkWell(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            onTap: () {
                                              _searchController.clear();
                                            },
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              alignment: Alignment.center,
                                              child: Icon(
                                                Icons.clear_rounded,
                                                color: context.colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.6),
                                                size: 20,
                                                semanticLabel: 'Clear search',
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                textInputAction: TextInputAction.search,
                                keyboardType: TextInputType.text,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (filteredLogs.isEmpty)
                        SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No logs match your search criteria.',
                                style: TextStyle(
                                  color: context.colorScheme.onSurface,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (
                              BuildContext context,
                              int index,
                            ) {
                              return LogLineCard(
                                logEntry: filteredLogs.elementAt(index),
                                index: index,
                              );
                            },
                            childCount: filteredLogs.length,
                          ),
                        ),
                    ],
                  ),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }
}

class LogLineCard extends StatelessWidget {
  const LogLineCard({
    required this.logEntry,
    required this.index,
    super.key,
  });

  final LogEntry logEntry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final timestamp = logEntry.createdAt.substring(0, 23);
    final domain = logEntry.domain;
    final subDomain = logEntry.subDomain;
    final message = logEntry.message;
    final color = logEntry.level == 'ERROR' ? context.colorScheme.error : null;

    return GestureDetector(
      onTap: () => beamToNamed('/settings/advanced/logging/${logEntry.id}'),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                timestamp,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '$domain $subDomain',
                style: TextStyle(
                  color: color,
                ),
              ),
              Text(
                message,
                style: TextStyle(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogDetailPage extends StatelessWidget {
  LogDetailPage({
    required this.logEntryId,
    super.key,
  });

  final LoggingDb _db = getIt<LoggingDb>();

  final String logEntryId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: TitleAppBar(title: context.messages.settingsLogsTitle),
      body: StreamBuilder(
        stream: _db.watchLogEntryById(logEntryId),
        builder: (
          BuildContext context,
          AsyncSnapshot<List<LogEntry>> snapshot,
        ) {
          LogEntry? logEntry;
          final data = snapshot.data ?? [];
          if (data.isNotEmpty) {
            logEntry = data.first;
          }

          if (logEntry == null) {
            return const EmptyScaffoldWithTitle('');
          }

          final timestamp = logEntry.createdAt.substring(0, 23);
          final domain = logEntry.domain;
          final level = logEntry.level;
          final subDomain = logEntry.subDomain;
          final message = logEntry.message;
          final stacktrace = logEntry.stacktrace;

          final clipboardText =
              '$timestamp $level $domain $subDomain\n\n$message\n\n$stacktrace';

          final headerStyle = level == 'ERROR'
              ? monospaceTextStyle.copyWith(
                  color: context.colorScheme.error,
                  fontWeight: FontWeight.bold,
                )
              : monospaceTextStyle;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Wrap(
                  children: [
                    Text(timestamp, style: headerStyle),
                    const SizedBox(width: 10),
                    Text(level, style: headerStyle),
                    const SizedBox(width: 10),
                    Text(domain, style: headerStyle),
                    if (subDomain != null) ...[
                      const SizedBox(width: 10),
                      Text(subDomain, style: headerStyle),
                    ],
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Message:'),
                ),
                SelectableText(message, style: monospaceTextStyle),
                if (stacktrace != null) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('Stack Trace:'),
                  ),
                  SelectableText(stacktrace, style: monospaceTextStyle),
                ],
                IconButton(
                  icon: Icon(MdiIcons.clipboardOutline),
                  iconSize: 48,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: clipboardText));
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
