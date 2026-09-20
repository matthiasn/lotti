import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/settings/ui/widgets/config_flag_toggle_list.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Mobile / drill-down wrapper for [SectionsBody] — supplies the page
/// chrome (title, back button) that the Settings V2 detail pane provides
/// itself. [SectionsBody] carries its own gutter, so this passes
/// [EdgeInsets.zero].
///
/// Unlike `FlagsPage` this does not need `fillRemaining`: the body is a
/// short fixed list with no pinned header above a scroll region, so the
/// default `SliverToBoxAdapter` host is the right one.
class SectionsPage extends StatelessWidget {
  const SectionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsSectionsTitle,
      showBackButton: true,
      child: const SectionsBody(),
    );
  }
}

/// *Settings → Sections* — the one place where a user turns a part of the
/// app on or off.
///
/// These toggles used to be seven rows among twenty-three on the Config
/// Flags page, three levels down under Advanced, where nobody looking for
/// Habits would think to go. The app's progressive disclosure only works if
/// the switch that reveals a feature is itself discoverable, so the rows that
/// add navigation destinations moved up to a page of their own near the top
/// of Settings, and Config Flags kept the preferences and the diagnostics.
///
/// The membership rule is [sectionFlags], not taste: a flag shows here when
/// `NavService` watches it to decide whether a tab exists. Row order matches
/// that navigation order, so the list reads the way the sidebar it builds
/// does.
class SectionsBody extends StatelessWidget {
  const SectionsBody({super.key, this.displayedItems = sectionFlags});

  /// Flag names to render, in display order.
  @visibleForTesting
  final List<String> displayedItems;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5).add(
        EdgeInsets.only(
          top: tokens.spacing.step4,
          bottom: tokens.spacing.step5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.messages.settingsSectionsIntro,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          StreamBuilder<Set<ConfigFlag>>(
            stream: getIt<JournalDb>().watchConfigFlags(),
            builder: (context, snapshot) {
              final flagLookup = <String, ConfigFlag>{
                for (final flag in snapshot.data ?? <ConfigFlag>{})
                  flag.name: flag,
              };
              // `nonNulls` drops a name the database has not stored yet —
              // the stream's first frame is empty, and a flag added to
              // `sectionFlags` ahead of `initConfigFlags` would otherwise
              // throw rather than simply not render.
              final orderedFlags = displayedItems
                  .map((name) => flagLookup[name])
                  .nonNulls
                  .toList();
              if (orderedFlags.isEmpty) return const SizedBox.shrink();
              return ConfigFlagToggleList(flags: orderedFlags);
            },
          ),
        ],
      ),
    );
  }
}
