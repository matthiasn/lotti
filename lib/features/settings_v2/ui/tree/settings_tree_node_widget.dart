import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/features/settings_v2/ui/tree/settings_tree_row.dart';

/// Per-row selector computed once per path mutation so the enclosing
/// `ref.watch` only rebuilds when *this* node's active/expanded state
/// actually flips. Avoids the whole tree rebuilding on every tap.
typedef _RowSelection = ({bool onActivePath, bool isExpanded});

/// Renders one [SettingsNode] and — for branches — its (animated)
/// children subtree. Reads the shared [settingsTreePathProvider] with a
/// `.select` narrowed to this node's slot so siblings do not rebuild
/// when selection moves elsewhere in the tree.
class SettingsTreeNodeWidget extends ConsumerWidget {
  const SettingsTreeNodeWidget({
    required this.node,
    required this.depth,
    super.key,
  });

  final SettingsNode node;
  final int depth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final selection = ref.watch(
      settingsTreePathProvider.select<_RowSelection>((path) {
        final onActivePath = depth < path.length && path[depth] == node.id;
        // A branch is expanded whenever it sits on the active path —
        // `onActivePath` already implies `depth < path.length`.
        return (
          onActivePath: onActivePath,
          isExpanded: node.hasChildren && onActivePath,
        );
      }),
    );
    final onActivePath = selection.onActivePath;
    final isExpanded = selection.isExpanded;

    void handleTap() {
      ref
          .read(settingsTreePathProvider.notifier)
          .onNodeTap(
            node.id,
            depth: depth,
            hasChildren: node.hasChildren,
          );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsTreeRow(
          node: node,
          depth: depth,
          onActivePath: onActivePath,
          isExpanded: isExpanded,
          onTap: handleTap,
        ),
        if (node.hasChildren)
          // Keep children mounted during the collapse so
          // `AnimatedOpacity` fades them out in step with
          // `AnimatedSize` shrinking the container. `ClipRect` +
          // `Align(heightFactor)` reveals/hides without cutting —
          // swapping in a `SizedBox` here would teleport the
          // content out instantly and only animate empty space.
          ClipRect(
            child: AnimatedSize(
              duration: SettingsV2Constants.branchSizeAnimation,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: isExpanded ? 1.0 : 0.0,
                child: AnimatedOpacity(
                  duration: SettingsV2Constants.branchOpacityAnimation,
                  opacity: isExpanded ? 1 : 0,
                  child: _ChildrenContainer(
                    children: node.children!,
                    depth: depth + 1,
                    tokens: tokens,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChildrenContainer extends StatelessWidget {
  const _ChildrenContainer({
    required this.children,
    required this.depth,
    required this.tokens,
  });

  final List<SettingsNode> children;
  final int depth;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step6,
        top: tokens.spacing.step3,
        bottom: tokens.spacing.step3,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: tokens.colors.interactive.enabled.withValues(
                alpha: SettingsV2Constants.childrenRailAlpha,
              ),
              width: SettingsV2Constants.childrenRailWidth,
            ),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.only(left: tokens.spacing.step4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                SettingsTreeNodeWidget(
                  key: ValueKey(child.id),
                  node: child,
                  depth: depth,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
