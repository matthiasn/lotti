import 'package:flutter/widgets.dart';

/// Inherited marker that signals a widget is being rendered as a column
/// inside the desktop settings multi-column stack.
///
/// The stack's root page already shows a single top bar with the leaf
/// title and breadcrumb trail, so per-page headers (e.g.
/// `SliverBoxAdapterPage`'s `SettingsPageHeader`) become redundant
/// inside a column. Any widget that would otherwise render its own
/// header can check for this scope with [SettingsColumnScope.of] and
/// suppress it when present.
///
/// Mobile (single-page push navigation) does not insert the scope, so
/// the existing per-page headers stay intact there.
class SettingsColumnScope extends InheritedWidget {
  const SettingsColumnScope({required super.child, super.key});

  /// Returns the nearest enclosing scope, or `null` when the widget is
  /// not rendered inside the desktop multi-column stack.
  static SettingsColumnScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SettingsColumnScope>();
  }

  @override
  bool updateShouldNotify(covariant SettingsColumnScope oldWidget) => false;
}
