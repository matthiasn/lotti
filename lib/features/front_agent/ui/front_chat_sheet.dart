import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/widgets/modal/side_sheet.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the companion's chat in the app-shell sheet (decision 3): the
/// agent-chat side sheet on a wide window, a bottom sheet below the page
/// breakpoint, over whatever tab the user is on — never an eleventh tab.
///
/// Pushed on the root navigator, so it dims the whole window and the same
/// call serves the sidebar, the phone launcher and the keyboard command.
Future<void> showFrontChatSheet(BuildContext context) =>
    showSideSheetPane<void>(
      context: context,
      sideSheet: kAgentChatSideSheet,
      // The composer's field needs a Material ancestor; the Scaffold also keeps
      // the keyboard inset honest on a phone-width window.
      builder: (sheetContext) => Scaffold(
        body: FrontChatPane(onClose: () => Navigator.of(sheetContext).pop()),
      ),
    );
