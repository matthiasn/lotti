import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/widgets/modal/side_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Opens a person's agent conversation in the shared side sheet — the same
/// panel a goal's conversation opens in. It slides in over the person page,
/// which stays in view behind the scrim instead of being squeezed into what a
/// docked chat column left of it.
Future<void> showRelationshipChatSheet(
  BuildContext context, {
  required String relationshipId,
}) => showSideSheetPane<void>(
  context: context,
  sideSheet: kAgentChatSideSheet,
  // The composer's field needs a Material ancestor; the Scaffold also keeps
  // the keyboard inset honest on a phone-width window.
  builder: (sheetContext) => Scaffold(
    body: RelationshipChatPane(
      relationshipId: relationshipId,
      onClose: () => Navigator.of(sheetContext).pop(),
      showInternalsAction: true,
    ),
  ),
);
