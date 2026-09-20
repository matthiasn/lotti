import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/profiles/state/profile_providers.dart';
import 'package:lotti/features/settings/ui/pages/sections_page.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_labels.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_toggle_list.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

export 'package:lotti/features/settings/ui/widgets/config_flag_labels.dart'
    show FlagLabelResolver;

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

/// The two jobs the Config Flags page still does, after the rows that turn
/// whole app sections on moved out to [SectionsBody].
///
/// The split is what stops this page reading as one undifferentiated list of
/// switches: a preference is something a user might reasonably want to change
/// about a feature they already have, while the second group is diagnostics
/// and unfinished work whose rows a user has no reason to touch unless asked
/// to. Group membership is declared once in [FlagsBody.groupedFlags] and
/// rendered in enum-declaration order.
enum ConfigFlagGroup { preferences, advanced }

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
/// keyword search bar plus the filtered, grouped flag list.
class FlagsBody extends ConsumerStatefulWidget {
  const FlagsBody({
    super.key,
    this.displayedGroups = groupedFlags,
  });

  /// Canonical render order for the flag list, by group. Adding a flag here
  /// also requires icon + title + subtitle wiring in `ConfigFlagLabels`; the
  /// modular flag tests assert each end of that chain.
  ///
  /// [sectionFlags] are deliberately absent — they render on *Settings →
  /// Sections* instead, near the top of the menu where someone looking for
  /// Habits will actually find them. A flag listed in both places would give
  /// the same stored value two homes, so the tests assert the two sets stay
  /// disjoint and that between them they cover every flag the app defines.
  static const Map<ConfigFlagGroup, List<String>> groupedFlags = {
    ConfigFlagGroup.preferences: [
      privateFlag,
      enableNotificationsFlag,
      recordLocationFlag,
      enableTooltipFlag,
      enableSessionRatingsFlag,
      enableWhatsNewFlag,
      enableAiStreamingFlag,
      enableAiSummaryTtsFlag,
      enableMatrixFlag,
    ],
    ConfigFlagGroup.advanced: [
      enableQueryChatFlag,
      enableEmbeddingsFlag,
      enableVectorSearchFlag,
      dailyOsOnboardingEnabledFlag,
      enableForkHealingFlag,
      enableLoggingFlag,
      resendAttachments,
    ],
  };

  /// Every flag this page renders, flattened across the groups in render
  /// order — the view the coverage and retirement checks read, and what
  /// callers that only care *whether* a flag is on this page should use.
  static List<String> get defaultDisplayedItems => [
    for (final group in ConfigFlagGroup.values) ...?groupedFlags[group],
  ];

  /// Flag names to render, grouped, in display order.
  @visibleForTesting
  final Map<ConfigFlagGroup, List<String>> displayedGroups;

  /// Flags that only make sense while the Matrix sync stack exists.
  /// Guest/demo worlds never construct it (see `ProfileCapabilities.guest`),
  /// so these rows are filtered out there — most importantly
  /// [enableMatrixFlag], whose toggle would otherwise resurrect the Sync
  /// settings surfaces against an absent `MatrixService`.
  static const Set<String> syncOnlyFlags = {
    enableMatrixFlag,
    resendAttachments,
  };

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

  String _groupLabel(BuildContext context, ConfigFlagGroup group) {
    switch (group) {
      case ConfigFlagGroup.preferences:
        return context.messages.settingsFlagsGroupPreferences;
      case ConfigFlagGroup.advanced:
        return context.messages.settingsFlagsGroupAdvanced;
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
              final syncAvailable = ref.watch(syncFeatureAvailableProvider);
              final orderedGroups = <ConfigFlagGroup, List<ConfigFlag>>{
                for (final group in ConfigFlagGroup.values)
                  group: (widget.displayedGroups[group] ?? const <String>[])
                      .where(
                        (name) =>
                            syncAvailable ||
                            !FlagsBody.syncOnlyFlags.contains(name),
                      )
                      .map((name) => flagLookup[name])
                      .nonNulls
                      .toList(),
              };
              if (orderedGroups.values.every((flags) => flags.isEmpty)) {
                return const SizedBox.shrink();
              }

              return ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  final resolver = ConfigFlagLabels.resolverFor(context);
                  final filteredGroups = <ConfigFlagGroup, List<ConfigFlag>>{
                    for (final entry in orderedGroups.entries)
                      entry.key: filterDisplayedFlags(
                        query: value.text,
                        flags: entry.value,
                        resolver: resolver,
                      ),
                  }..removeWhere((_, flags) => flags.isEmpty);

                  if (filteredGroups.isEmpty) {
                    return Padding(
                      padding: pageGutter,
                      child: const _FlagsEmptySearch(),
                    );
                  }
                  return SingleChildScrollView(
                    padding:
                        pageGutter +
                        EdgeInsets.only(bottom: tokens.spacing.step5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (index, entry)
                            in filteredGroups.entries.indexed) ...[
                          if (index > 0)
                            SizedBox(height: tokens.spacing.sectionGap),
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: tokens.spacing.step2,
                            ),
                            child: Text(
                              _groupLabel(context, entry.key),
                              style: calmEyebrowStyle(tokens),
                            ),
                          ),
                          ConfigFlagToggleList(flags: entry.value),
                        ],
                      ],
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

/// Empty-state shown when the search query matches no flag.
///
/// The second line is not decoration: the section toggles (Habits, Projects,
/// Daily OS, …) used to live on this page, so someone who learned to find
/// them here searches here first and now finds nothing. Pointing at their new
/// home is what keeps the move from reading as a removal.
class _FlagsEmptySearch extends StatelessWidget {
  const _FlagsEmptySearch();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.messages.settingsFlagsEmptySearch,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            context.messages.settingsFlagsEmptySearchSectionsHint,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
