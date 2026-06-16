import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/user_activity/state/user_activity_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

/// Legacy scaffold for the mobile / drill-down settings sub-pages.
///
/// Wraps [child] in a `Scaffold` + `CustomScrollView` with a
/// `SettingsPageHeader` (title, optional back button, optional [actions])
/// and fades the body in over 500ms. Scroll activity is forwarded to the
/// [UserActivityService] so settings browsing keeps the idle timer alive.
///
/// Used by the `*Page` wrappers (`FlagsPage`, `ThemingPage`, `AboutPage`,
/// `MaintenancePage`, `LoggingSettingsPage`, `HealthImportPage`) that pair
/// chrome here with a chrome-free `*Body` embedded by settings_v2. See
/// [fillRemaining] for the bounded vs. unbounded body-height modes.
class SliverBoxAdapterPage extends StatefulWidget {
  const SliverBoxAdapterPage({
    required this.child,
    required this.title,
    this.subtitle,
    this.showBackButton = false,
    this.padding = EdgeInsets.zero,
    this.actions,
    this.fillRemaining = false,
    super.key,
  });

  final Widget child;
  final String title;
  final String? subtitle;
  final bool showBackButton;
  final EdgeInsets padding;
  final List<Widget>? actions;

  /// When `true`, the body is hosted inside a
  /// `SliverFillRemaining(hasScrollBody: true)` — the body claims the
  /// remaining viewport height as a *bounded* constraint instead of
  /// the default `SliverToBoxAdapter` (unbounded). Use this for pages
  /// whose body needs `Expanded` / `Flexible` children (e.g. a fixed
  /// header above a scrollable list). The bottom-nav-occupied space
  /// is folded into the body's bottom padding so a sub-list doesn't
  /// render under the nav bar.
  final bool fillRemaining;

  @override
  State<SliverBoxAdapterPage> createState() => _SliverBoxAdapterPageState();
}

class _SliverBoxAdapterPageState extends State<SliverBoxAdapterPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    final listener = getIt<UserActivityService>().updateActivity;
    _scrollController.addListener(listener);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavHeight = DesignSystemBottomNavigationBar.occupiedHeight(
      context,
    );
    final fadedChild = widget.child.animate().fadeIn(
      duration: const Duration(milliseconds: 500),
    );

    return Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SettingsPageHeader(
            title: widget.title,
            subtitle: widget.subtitle,
            showBackButton: widget.showBackButton,
            actions: widget.actions,
          ),
          if (widget.fillRemaining)
            SliverFillRemaining(
              // In fill-remaining mode the outer CustomScrollView never
              // scrolls (FillRemaining claims the viewport), so the
              // controller listener above can't observe activity from
              // the inner scrollable. Bridge it via ScrollNotification
              // so user-activity tracking still fires on body scroll.
              child: NotificationListener<ScrollNotification>(
                onNotification: (_) {
                  getIt<UserActivityService>().updateActivity();
                  return false;
                },
                child: Padding(
                  // Fold the bottom-nav spacer into the body's padding so
                  // a child ListView's last row doesn't render under the
                  // nav bar. The trailing SliverToBoxAdapter spacer is
                  // unreachable in this mode (FillRemaining ate the
                  // remaining viewport).
                  padding:
                      EdgeInsets.only(bottom: bottomNavHeight) + widget.padding,
                  child: fadedChild,
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: widget.padding,
                child: fadedChild,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(height: bottomNavHeight),
            ),
          ],
        ],
      ),
    );
  }
}
