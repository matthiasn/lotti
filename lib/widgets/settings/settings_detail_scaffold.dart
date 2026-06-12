import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/app_bar/settings_page_header.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';
import 'package:lotti/widgets/settings/settings_form_action_bar.dart';
import 'package:lotti/widgets/settings/settings_page_layout.dart';

/// Unified shell for settings definition detail pages (category, label,
/// habit, measurable, dashboard editors).
///
/// One silhouette for every editor:
///
/// * [SettingsPageHeader] with a back affordance that beams to the list
///   route (works on mobile and inside the desktop split pane, where the
///   page mounts inline without a Navigator route),
/// * a scrollable content column aligned to the header grid
///   ([SettingsContentSliver]) — pass [children] for the common
///   box-widget form, or [slivers] for pages that need lazy/sliver
///   content (each sliver is mounted as-is; wrap in
///   [SettingsContentSliver] to stay on the grid),
/// * a sticky [SettingsFormActionBar] floating on blurred glass at the
///   bottom (`extendBody` is set so the form scrolls behind it), and
/// * Cmd/Ctrl+S bound to [onSaveShortcut].
class SettingsDetailScaffold extends StatelessWidget {
  const SettingsDetailScaffold({
    required this.title,
    required this.onBack,
    this.subtitle,
    this.children,
    this.slivers,
    this.actionBar,
    this.onSaveShortcut,
    this.headerActions,
    this.deleteLabel,
    this.onDelete,
    this.deleteEnabled = true,
    super.key,
  }) : assert(
         (children == null) != (slivers == null),
         'Provide exactly one of children or slivers.',
       ),
       assert(
         (deleteLabel == null) == (onDelete == null),
         'deleteLabel and onDelete must be provided together.',
       );

  /// Header title (e.g. "Edit habit").
  final String title;

  /// Optional header subtitle shown under the title while expanded.
  final String? subtitle;

  /// Back affordance handler. Detail pages beam to their list route so the
  /// desktop split pane (inline mount, no Navigator route) stays in sync.
  final VoidCallback onBack;

  /// Form content as box widgets, laid out in a single aligned column.
  final List<Widget>? children;

  /// Full sliver control for pages with lazy content (e.g. reorderable
  /// dashboard items). Mutually exclusive with [children].
  final List<Widget>? slivers;

  /// The sticky glass action bar, typically a [SettingsFormActionBar].
  final SettingsFormActionBar? actionBar;

  /// Bound to Cmd+S / Ctrl+S. Usually the same handler as the action
  /// bar's primary action.
  final VoidCallback? onSaveShortcut;

  /// Optional trailing header widgets.
  final List<Widget>? headerActions;

  /// Optional destructive action, rendered as a [SettingsDeleteRow] at
  /// the very end of the form — the conventional, deliberate home for
  /// Delete, fully separated from the sticky bar's save flow.
  final String? deleteLabel;
  final VoidCallback? onDelete;
  final bool deleteEnabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final scaffold = Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      // extendBody so the BackdropFilter inside the action bar's glass
      // strip has body content underneath to actually blur. The Scaffold
      // then reports the bar's height via the body MediaQuery's bottom
      // padding, which the trailing clearance sliver consumes below.
      extendBody: true,
      body: Builder(
        builder: (context) {
          // Read inside the Scaffold body so the value includes the
          // bottomNavigationBar slot height added by extendBody.
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          return CustomScrollView(
            slivers: [
              SettingsPageHeader(
                title: title,
                subtitle: subtitle,
                showBackButton: true,
                onBack: onBack,
                actions: headerActions,
              ),
              SliverToBoxAdapter(
                child: SizedBox(height: tokens.spacing.step5),
              ),
              if (children != null)
                SettingsContentSliver(
                  sliver: SliverList(
                    delegate: SliverChildListDelegate(children!),
                  ),
                )
              else
                ...slivers!,
              if (onDelete != null)
                SettingsContentSliver(
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(top: tokens.spacing.step4),
                      child: SettingsDeleteRow(
                        label: deleteLabel!,
                        onTap: onDelete!,
                        enabled: deleteEnabled,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(height: bottomInset + tokens.spacing.step6),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: actionBar,
    );

    if (onSaveShortcut == null) return scaffold;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true):
            onSaveShortcut!,
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
            onSaveShortcut!,
      },
      child: scaffold,
    );
  }
}
