import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/pages/empty_scaffold.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/app_bar/sliver_title_bar.dart';
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

                return CustomScrollView(
                  slivers: <Widget>[
                    SliverTitleBar(
                      context.messages.settingsLogsTitle,
                      pinned: true,
                      showBackButton: true,
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (
                          BuildContext context,
                          int index,
                        ) {
                          return LogLineCard(
                            logEntry: logEntries.elementAt(index),
                            index: index,
                          );
                        },
                        childCount: logEntries.length,
                      ),
                    ),
                  ],
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Text(
          '$timestamp: $domain $subDomain $message',
          style: monospaceTextStyleSmall.copyWith(color: color),
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
