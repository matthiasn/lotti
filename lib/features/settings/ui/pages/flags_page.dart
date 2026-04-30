import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/settings_icon.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/consts.dart';

/// Mobile / legacy wrapper — keeps the `SliverBoxAdapterPage` chrome
/// (title, back button, page-level padding) and delegates the
/// content to [FlagsBody] so the same widget can be hosted inside the
/// Settings V2 detail pane (plan step 7).
///
/// Uses `fillRemaining: true` so the chrome gives the body a bounded
/// height — the search field stays pinned while only the rows below
/// it scroll. [FlagsBody] applies its own internal horizontal +
/// vertical padding so this wrapper passes [EdgeInsets.zero].
class FlagsPage extends StatelessWidget {
  const FlagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsFlagsTitle,
      showBackButton: true,
      fillRemaining: true,
      child: const FlagsBody(),
    );
  }
}

/// Resolves a [ConfigFlag] into a localized (title, subtitle) pair.
/// Extracted so the search filter and the rendering path share a
/// single source of truth — and so the per-flag wiring stays
/// trivially unit-testable.
typedef FlagLabelResolver =
    ({String title, String subtitle}) Function(ConfigFlag flag);

/// Filters [flags] by a search [query] applied to each flag's
/// resolved title and subtitle.
///
/// Behavior locked in by the unit tests:
///
/// - An empty or whitespace-only query returns [flags] unchanged
///   (preserving order).
/// - The query is trimmed and lower-cased before matching.
/// - A flag is included when its resolved title OR subtitle contains
///   the normalized query as a substring (case-insensitive).
///
/// Pure function — takes the resolver as a parameter so tests can
/// supply a deterministic title/subtitle map without spinning up
/// `AppLocalizations`.
List<ConfigFlag> filterDisplayedFlags({
  required String query,
  required List<ConfigFlag> flags,
  required FlagLabelResolver resolver,
}) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) return flags;
  return [
    for (final flag in flags)
      if (_flagMatchesQuery(flag, normalized, resolver)) flag,
  ];
}

bool _flagMatchesQuery(
  ConfigFlag flag,
  String normalizedQuery,
  FlagLabelResolver resolver,
) {
  final label = resolver(flag);
  return label.title.toLowerCase().contains(normalizedQuery) ||
      label.subtitle.toLowerCase().contains(normalizedQuery);
}

/// Content body for the feature-flags settings. Extracted from
/// [FlagsPage] so it can be rendered inside the V2 detail pane
/// without the surrounding `SliverBoxAdapterPage` chrome. Hosts the
/// keyword search bar plus the filtered flag list.
class FlagsBody extends ConsumerStatefulWidget {
  const FlagsBody({super.key});

  /// Canonical render order for the flag list. Adding a flag here
  /// also requires icon + title + subtitle wiring below; the
  /// modular flag tests assert each end of that chain.
  static const List<String> displayedItems = [
    privateFlag,
    enableNotificationsFlag,
    recordLocationFlag,
    enableTooltipFlag,
    enableAiStreamingFlag,
    enableLoggingFlag,
    enableMatrixFlag,
    resendAttachments,
    useCompressedJsonAttachmentsFlag,
    useOutboxBundlingFlag,
    enableHabitsPageFlag,
    enableDashboardsPageFlag,
    enableDailyOsPageFlag,
    enableEventsFlag,
    enableSessionRatingsFlag,
    enableAgentsFlag,
    enableProjectsFlag,
    enableEmbeddingsFlag,
    enableVectorSearchFlag,
    enableWhatsNewFlag,
  ];

  @override
  ConsumerState<FlagsBody> createState() => _FlagsBodyState();
}

class _FlagsBodyState extends ConsumerState<FlagsBody> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _iconForFlag(String flagName) {
    switch (flagName) {
      case privateFlag:
        return Icons.lock_outline_rounded;
      case enableNotificationsFlag:
        return Icons.notifications_active_rounded;
      case recordLocationFlag:
        return Icons.map_rounded;
      case enableTooltipFlag:
        return Icons.info_outline_rounded;
      case enableAiStreamingFlag:
        return Icons.bolt_rounded;
      case enableLoggingFlag:
        return Icons.bug_report_rounded;
      case enableMatrixFlag:
        return Icons.sync_rounded;
      case resendAttachments:
        return Icons.refresh_rounded;
      case useCompressedJsonAttachmentsFlag:
        return Icons.compress_rounded;
      case useOutboxBundlingFlag:
        return Icons.archive_outlined;
      case enableHabitsPageFlag:
        return Icons.repeat_rounded;
      case enableDashboardsPageFlag:
        return Icons.dashboard_rounded;
      case enableDailyOsPageFlag:
        return Icons.calendar_today_rounded;
      case enableEventsFlag:
        return Icons.event_rounded;
      case enableSessionRatingsFlag:
        return Icons.star_rate_rounded;
      case enableAgentsFlag:
        return Icons.smart_toy_outlined;
      case enableProjectsFlag:
        return Icons.folder_outlined;
      case enableEmbeddingsFlag:
        return Icons.hub_outlined;
      case enableVectorSearchFlag:
        return Icons.manage_search_rounded;
      case enableWhatsNewFlag:
        return Icons.new_releases_outlined;
      default:
        return Icons.settings;
    }
  }

  String _subtitleForFlag(BuildContext context, ConfigFlag flag) {
    switch (flag.name) {
      case privateFlag:
        return context.messages.configFlagPrivateDescription;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotificationsDescription;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocationDescription;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltipDescription;
      case enableAiStreamingFlag:
        return context.messages.configFlagEnableAiStreamingDescription;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLoggingDescription;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrixDescription;
      case resendAttachments:
        return context.messages.configFlagResendAttachmentsDescription;
      case useCompressedJsonAttachmentsFlag:
        return context
            .messages
            .configFlagUseCompressedJsonAttachmentsDescription;
      case useOutboxBundlingFlag:
        return context.messages.configFlagUseOutboxBundlingDescription;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPageDescription;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPageDescription;
      case enableDailyOsPageFlag:
        return context.messages.configFlagEnableDailyOsDescription;
      case enableEventsFlag:
        return context.messages.configFlagEnableEventsDescription;
      case enableSessionRatingsFlag:
        return context.messages.configFlagEnableSessionRatingsDescription;
      case enableAgentsFlag:
        return context.messages.configFlagEnableAgentsDescription;
      case enableProjectsFlag:
        return context.messages.configFlagEnableProjectsDescription;
      case enableEmbeddingsFlag:
        return context.messages.configFlagAttemptEmbeddingDescription;
      case enableVectorSearchFlag:
        return context.messages.configFlagEnableVectorSearchDescription;
      case enableWhatsNewFlag:
        return context.messages.configFlagEnableWhatsNewDescription;
      default:
        return flag.description;
    }
  }

  String _titleForFlag(BuildContext context, ConfigFlag flag) {
    switch (flag.name) {
      case privateFlag:
        return context.messages.configFlagPrivate;
      case enableNotificationsFlag:
        return context.messages.configFlagEnableNotifications;
      case recordLocationFlag:
        return context.messages.configFlagRecordLocation;
      case enableTooltipFlag:
        return context.messages.configFlagEnableTooltip;
      case enableAiStreamingFlag:
        return context.messages.configFlagEnableAiStreaming;
      case enableLoggingFlag:
        return context.messages.configFlagEnableLogging;
      case enableMatrixFlag:
        return context.messages.configFlagEnableMatrix;
      case resendAttachments:
        return context.messages.configFlagResendAttachments;
      case useCompressedJsonAttachmentsFlag:
        return context.messages.configFlagUseCompressedJsonAttachments;
      case useOutboxBundlingFlag:
        return context.messages.configFlagUseOutboxBundling;
      case enableHabitsPageFlag:
        return context.messages.configFlagEnableHabitsPage;
      case enableDashboardsPageFlag:
        return context.messages.configFlagEnableDashboardsPage;
      case enableDailyOsPageFlag:
        return context.messages.configFlagEnableDailyOs;
      case enableEventsFlag:
        return context.messages.configFlagEnableEvents;
      case enableSessionRatingsFlag:
        return context.messages.configFlagEnableSessionRatings;
      case enableAgentsFlag:
        return context.messages.configFlagEnableAgents;
      case enableProjectsFlag:
        return context.messages.configFlagEnableProjects;
      case enableEmbeddingsFlag:
        return context.messages.configFlagEnableEmbeddings;
      case enableVectorSearchFlag:
        return context.messages.configFlagEnableVectorSearch;
      case enableWhatsNewFlag:
        return context.messages.configFlagEnableWhatsNew;
      default:
        return flag.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // Horizontal page gutter — the search field and the list both
    // honour it so cards never reach the screen edge.
    final pageGutter = EdgeInsets.symmetric(horizontal: tokens.spacing.step5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pinned search field. Sits inside the bounded fill-remaining
        // host so it stays put while only the list below it scrolls.
        Padding(
          padding:
              pageGutter +
              EdgeInsets.only(
                top: tokens.spacing.step4,
                bottom: tokens.spacing.step4,
              ),
          child: DesignSystemSearch(
            hintText: context.messages.settingsFlagsSearchHint,
            controller: _searchController,
          ),
        ),
        // Scrollable list region — claims the rest of the bounded
        // height the host gave us.
        Expanded(
          child: StreamBuilder<Set<ConfigFlag>>(
            stream: getIt<JournalDb>().watchConfigFlags(),
            builder: (context, snapshot) {
              final flagLookup = <String, ConfigFlag>{
                for (final flag in snapshot.data ?? <ConfigFlag>{})
                  flag.name: flag,
              };
              final orderedFlags = FlagsBody.displayedItems
                  .map((name) => flagLookup[name])
                  .nonNulls
                  .toList();
              if (orderedFlags.isEmpty) return const SizedBox.shrink();

              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  final filteredFlags = filterDisplayedFlags(
                    query: value.text,
                    flags: orderedFlags,
                    resolver: (flag) => (
                      title: _titleForFlag(context, flag),
                      subtitle: _subtitleForFlag(context, flag),
                    ),
                  );
                  if (filteredFlags.isEmpty) {
                    return Padding(
                      padding: pageGutter,
                      child: const _FlagsEmptySearch(),
                    );
                  }
                  return SingleChildScrollView(
                    padding:
                        pageGutter +
                        EdgeInsets.only(bottom: tokens.spacing.step5),
                    child: _FlagsList(
                      flags: filteredFlags,
                      iconFor: _iconForFlag,
                      titleFor: (flag) => _titleForFlag(context, flag),
                      subtitleFor: (flag) => _subtitleForFlag(context, flag),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Renders the bordered, rounded list of flag rows. Pulled out as a
/// dedicated widget so the empty-search and populated branches stay
/// readable in [_FlagsBodyState.build] and the list shape is easy to
/// inspect from tests.
class _FlagsList extends StatefulWidget {
  const _FlagsList({
    required this.flags,
    required this.iconFor,
    required this.titleFor,
    required this.subtitleFor,
  });

  final List<ConfigFlag> flags;
  final IconData Function(String flagName) iconFor;
  final String Function(ConfigFlag flag) titleFor;
  final String Function(ConfigFlag flag) subtitleFor;

  @override
  State<_FlagsList> createState() => _FlagsListState();
}

class _FlagsListState extends State<_FlagsList> {
  /// Index of the currently-hovered flag row, or `null` when no row is
  /// hovered. Used to fade the divider between the hovered row and the
  /// row below it so the hovered row is never bisected by a hairline.
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final flags = widget.flags;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(tokens.radii.m),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (index, flag) in flags.indexed)
              DesignSystemListItem(
                title: widget.titleFor(flag),
                subtitle: widget.subtitleFor(flag),
                // `null` lifts the default single-line cap so long
                // descriptions ("Generate AI summary for task actions",
                // etc.) wrap onto a second / third line instead of
                // truncating with ellipsis.
                subtitleMaxLines: null,
                leading: SettingsIcon(icon: widget.iconFor(flag.name)),
                trailing: Switch.adaptive(
                  value: flag.status,
                  onChanged: (bool status) {
                    getIt<PersistenceLogic>().setConfigFlag(
                      flag.copyWith(status: status),
                    );
                  },
                ),
                onTap: () {
                  getIt<PersistenceLogic>().setConfigFlag(
                    flag.copyWith(status: !flag.status),
                  );
                },
                onHoverChanged: (hovered) {
                  setState(() {
                    if (hovered) {
                      _hoveredIndex = index;
                    } else if (_hoveredIndex == index) {
                      _hoveredIndex = null;
                    }
                  });
                },
                // Keep `showDivider` stable so layout doesn't shift by
                // 1 px on hover; fade the divider to transparent when
                // either this row or the row below it is hovered, so
                // the hovered row is never bisected by a hairline.
                showDivider: index < flags.length - 1,
                dividerColor:
                    (_hoveredIndex == index || _hoveredIndex == index + 1)
                    ? Colors.transparent
                    : null,
                dividerIndent: SettingsIcon.dividerIndent(tokens),
              ),
          ],
        ),
      ),
    );
  }
}

/// Empty-state shown when the search query matches no flag.
class _FlagsEmptySearch extends StatelessWidget {
  const _FlagsEmptySearch();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
      child: Center(
        child: Text(
          context.messages.settingsFlagsEmptySearch,
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
