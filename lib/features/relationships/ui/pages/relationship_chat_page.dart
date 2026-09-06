import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The relationship agent's conversation as a phone route — the shared
/// [RelationshipChatPane] with the back behaviour this layout needs.
///
/// There is no app bar: the pane's own identity header is the header
/// (design 2026-09-06 artboard 1e), and it carries the back affordance. On
/// desktop the same pane renders inside the People detail pane instead, so
/// this page is never reached there.
class RelationshipChatPage extends ConsumerWidget {
  const RelationshipChatPage({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailPath = '/people/$relationshipId';
    final page = Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: DesignSystemBottomNavigationBar.occupiedHeight(context),
          ),
          child: RelationshipChatPane(
            relationshipId: relationshipId,
            onBack: () => beamToNamed(detailPath),
            showInternalsAction: true,
          ),
        ),
      ),
    );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => beamToNamed(detailPath),
        );
      },
      child: page,
    );
  }
}
