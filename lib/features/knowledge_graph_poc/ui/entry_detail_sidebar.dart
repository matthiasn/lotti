import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/pages/entry_details_page.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';

/// Right-side overlay that opens the focused graph node's FULL details by
/// embedding the app's actual detail page — [TaskDetailsPage] for tasks,
/// [EntryDetailsPage] for any other entry — at a narrow, mobile-style width.
/// Rendered above the navigational inspector; [onClose] dismisses it.
///
/// The page is hosted in a nested [Navigator] so its own navigation (back,
/// linked-task pushes, the hub button) stays contained in the panel instead of
/// taking over the graph route. This is integration glue around the app's own
/// detail pages (which carry their own tests); only the load/error/empty shells
/// live here.
class EntryDetailSidebar extends ConsumerWidget {
  const EntryDetailSidebar({
    required this.entryId,
    required this.onClose,
    required this.tokens,
    super.key,
  });

  final String entryId;
  final VoidCallback onClose;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(entryControllerProvider(id: entryId));
    final radius = BorderRadius.circular(tokens.radii.l);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withValues(alpha: 0.4),
            blurRadius: 48,
            spreadRadius: -8,
            offset: const Offset(-16, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.colors.background.level01,
            borderRadius: radius,
            border: Border.all(color: tokens.colors.decorative.level01),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Stack(
              children: [
                Positioned.fill(
                  child: state.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => _Message(
                      text: "Couldn't load this entry",
                      tokens: tokens,
                    ),
                    data: (entryState) {
                      final item = entryState?.entry;
                      if (item == null) {
                        return _Message(
                          text: 'Entry not found',
                          tokens: tokens,
                        );
                      }
                      return _EmbeddedDetailPage(item: item, entryId: entryId);
                    },
                  ),
                ),
                // Close affordance — top-left, where the desktop detail app bar
                // keeps no leading, so it doesn't collide with the page chrome.
                Positioned(
                  top: tokens.spacing.step3,
                  left: tokens.spacing.step3,
                  child: _CloseButton(onClose: onClose, tokens: tokens),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose, required this.tokens});

  final VoidCallback onClose;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: tokens.colors.background.level02.withValues(alpha: 0.8),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onClose,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step2),
          child: Icon(
            Icons.close_rounded,
            size: 18,
            color: tokens.colors.text.highEmphasis,
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.tokens});

  final String text;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step6),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

/// Hosts the app's real detail PAGE for [item] in a self-contained [Navigator]
/// so the page's own back / pushes stay inside the panel. The pages bring their
/// own Scaffold + chrome and are exercised by their own tests, so this thin
/// embedding shell is excluded from coverage.
class _EmbeddedDetailPage extends StatelessWidget {
  const _EmbeddedDetailPage({required this.item, required this.entryId});

  final JournalEntity item;
  final String entryId;

  @override
  Widget build(BuildContext context) {
    // coverage:ignore-start
    return Navigator(
      onGenerateRoute: (_) => MaterialPageRoute<void>(
        builder: (_) => item is Task
            ? TaskDetailsPage(taskId: entryId)
            : EntryDetailsPage(itemId: entryId),
      ),
    );
    // coverage:ignore-end
  }
}
