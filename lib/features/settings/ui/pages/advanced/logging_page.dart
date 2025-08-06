import 'dart:async';

import 'package:extended_sliver/extended_sliver.dart';
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

class LoggingPage extends StatefulWidget {
  const LoggingPage({super.key});

  @override
  State<LoggingPage> createState() => _LoggingPageState();
}

class _LoggingPageState extends State<LoggingPage> {
  bool _isVisible = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  // Pagination state
  final List<LogEntry> _allLogEntries = [];
  final List<LogEntry> _searchResults = [];
  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMoreResults = true;
  int _totalSearchResults = 0;
  bool _isSearching = false;

  // Constants for validation and pagination
  static const int _maxSearchLength = 200;
  static const Duration _debounceDelay = Duration(milliseconds: 300);
  static const int _pageSize = 50; // Optimal page size for performance

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChange);
    _loadInitialData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleSearchChange() {
    // Cancel the previous timer
    _debounceTimer?.cancel();

    // Start a new timer for debouncing
    _debounceTimer = Timer(_debounceDelay, () {
      final query = _searchController.text.trim();

      // Validate input length
      if (query.length <= _maxSearchLength) {
        setState(() {
          _searchQuery = query;
        });
        _performSearch();
      } else {
        // Show error for overly long queries
        _showSearchError(
            'Search query too long (max $_maxSearchLength characters)');
      }
    });
  }

  void _showSearchError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: context.colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      // Load recent logs (non-search mode)
      final recentLogs = await getIt<LoggingDb>().watchLogEntries().first;
      _allLogEntries
        ..clear()
        ..addAll(recentLogs);
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      const errorMessage = 'Failed to load logs. Please try again.';
      setState(() {
        _isSearching = false;
      });
      _showSearchError(errorMessage);
    }
  }

  Future<void> _performSearch() async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _searchResults.clear();
      _currentOffset = 0;
      _hasMoreResults = true;
    });

    try {
      if (_searchQuery.isEmpty) {
        // Switch back to recent logs mode
        await _loadInitialData();
        return;
      }

      // Get total count for pagination info
      final totalCount =
          await getIt<LoggingDb>().getSearchLogEntriesCount(_searchQuery);

      // Load first page of search results
      final firstPage = await getIt<LoggingDb>()
          .watchSearchLogEntriesPaginated(_searchQuery)
          .first;

      if (mounted) {
        _searchResults
          ..clear()
          ..addAll(firstPage);
        setState(() {
          _totalSearchResults = totalCount;
          _currentOffset = firstPage.length;
          _hasMoreResults = firstPage.length >= _pageSize;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      const errorMessage = 'Search failed. Please try again.';
      setState(() {
        _isSearching = false;
      });
      _showSearchError(errorMessage);
    }
  }

  Future<void> _loadMoreResults() async {
    if (!mounted ||
        _isLoadingMore ||
        !_hasMoreResults ||
        _searchQuery.isEmpty) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreResults = await getIt<LoggingDb>()
          .watchSearchLogEntriesPaginated(
            _searchQuery,
            offset: _currentOffset,
          )
          .first;

      if (mounted) {
        setState(() {
          _searchResults.addAll(moreResults);
          _currentOffset += moreResults.length;
          _hasMoreResults = moreResults.length >= _pageSize;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      const errorMessage = 'Failed to load more results. Please try again.';
      setState(() {
        _isLoadingMore = false;
      });
      _showSearchError(errorMessage);
    }
  }

  List<LogEntry> get _currentEntries {
    return _searchQuery.isEmpty ? _allLogEntries : _searchResults;
  }

  Widget _buildContent() {
    if (_isSearching) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                CircularProgressIndicator(
                  color: context.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'Loading recent logs...'
                      : 'Searching logs...',
                  style: TextStyle(
                    color: context.colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final entries = _currentEntries;

    if (entries.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Icon(
                  _searchQuery.isEmpty
                      ? Icons.inbox_outlined
                      : Icons.search_off,
                  size: 48,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isEmpty
                      ? 'No logs available'
                      : 'No logs match your search',
                  style: TextStyle(
                    color: context.colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_searchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Try different keywords or check your spelling',
                    style: TextStyle(
                      color: context.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (BuildContext context, int index) {
          // Show search results count as first item
          if (index == 0 && _searchQuery.isNotEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Found $_totalSearchResults log${_totalSearchResults == 1 ? '' : 's'} (showing ${entries.length})',
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          // Adjust index for log entries (subtract 1 for the count header)
          final logIndex = _searchQuery.isNotEmpty ? index - 1 : index;

          // Check if we need to load more results
          if (_searchQuery.isNotEmpty &&
              logIndex >= entries.length - 5 &&
              _hasMoreResults &&
              !_isLoadingMore) {
            // Load more results when user is near the end
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _loadMoreResults();
            });
          }

          if (logIndex < 0 || logIndex >= entries.length) {
            // Show loading indicator at the end if loading more
            if (_isLoadingMore) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(
                    color: context.colorScheme.primary,
                  ),
                ),
              );
            }
            return null;
          }

          return LogLineCard(
            logEntry: entries[logIndex],
            index: logIndex,
          );
        },
        childCount: _searchQuery.isNotEmpty
            ? entries.length + 1 + (_isLoadingMore ? 1 : 0)
            : entries.length + (_isLoadingMore ? 1 : 0),
      ),
    );
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
          ? Scaffold(
              backgroundColor: Theme.of(context).brightness == Brightness.light
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
                                ? context.colorScheme.surfaceContainerHighest
                                : null,
                            gradient: Theme.of(context).brightness ==
                                    Brightness.light
                                ? null
                                : LinearGradient(
                                    colors: [
                                      context.colorScheme.surfaceContainer,
                                      context.colorScheme.surfaceContainerHigh
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
                              hintText: 'Search all logs...',
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
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: _searchController.clear,
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          child: Icon(
                                            Icons.clear_rounded,
                                            color: context
                                                .colorScheme.onSurfaceVariant
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
                            maxLength: _maxSearchLength,
                            buildCounter: (context,
                                    {required currentLength,
                                    required isFocused,
                                    maxLength}) =>
                                null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildContent(),
                ],
              ),
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
