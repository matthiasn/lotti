import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_ui/material_ui.dart';

class TitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleAppBar({
    required this.title,
    super.key,
    this.showBackButton = true,
    this.actions,
  });

  final String title;
  final bool showBackButton;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return TitleWidgetAppBar(
      showBackButton: showBackButton,
      actions: actions,
      title: Text(
        title,
        style: appBarTextStyleNew,
      ),
    );
  }
}

class TitleWidgetAppBar extends StatelessWidget implements PreferredSizeWidget {
  const TitleWidgetAppBar({
    required this.title,
    super.key,
    this.showBackButton = true,
    this.actions,
    this.margin = const EdgeInsets.symmetric(horizontal: 70),
  });

  final Widget title;
  final bool showBackButton;
  final List<Widget>? actions;
  final EdgeInsets margin;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: actions,
      automaticallyImplyLeading: false,
      scrolledUnderElevation: 10,
      titleSpacing: 0,
      leadingWidth: 100,
      title: Container(
        margin: margin,
        child: title,
      ),
      leading: showBackButton ? const BackWidget() : Container(),
      centerTitle: true,
    );
  }
}

/// Whether the page around [context] was pushed with [Navigator.push] rather
/// than placed by Beamer — so its back is a pop, back to whatever pushed it,
/// not a beam back through the tab's history. A navigator's first route has
/// nothing under it to pop back to, so it never counts.
bool isPushedPage(BuildContext context) {
  final route = ModalRoute.of(context);
  return route is PageRoute && route.settings is! Page && !route.isFirst;
}

class BackWidget extends ConsumerWidget {
  const BackWidget({
    super.key,
    this.onPressed,
    this.enabled = true,
  });

  /// Optional override for the back action. Defaults to a pop for a pushed
  /// page ([isPushedPage]) and to `NavService.beamBack()` for one Beamer
  /// placed.
  final VoidCallback? onPressed;

  /// Whether the arrow responds. A page holds it off while a write it must
  /// not abandon is in flight.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final action = enabled
        ? onPressed ??
              (isPushedPage(context)
                  ? () => Navigator.of(context).pop()
                  : () => ref.read(navServiceProvider).beamBack())
        : null;
    final tooltip = MaterialLocalizations.of(context).backButtonTooltip;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 2),
        Semantics(
          label: tooltip,
          button: true,
          enabled: enabled,
          excludeSemantics: true,
          onTap: action,
          child: IconButton(
            onPressed: action,
            tooltip: tooltip,
            icon: Icon(
              LottiIcons.chevronLeft,
              size: 30,
              weight: 500,
              // onSurfaceVariant, not outline: the chevron is an
              // interactive control and must clear the 3:1 non-text
              // contrast minimum on both themes.
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
