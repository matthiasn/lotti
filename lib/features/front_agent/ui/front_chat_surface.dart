import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/ui/front_chat_pane.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_escape_scope.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the companion over the app, as History opens: behind the shared
/// scrim, a large panel on a desktop window and the whole screen on a phone
/// — her own surface, never an eleventh tab.
///
/// On the root navigator, so the same call serves the sidebar, the phone
/// launcher and the keyboard command. Escape asks the pane to go back first
/// (the list, then the inbox) before it closes her.
Future<void> showFrontChat(BuildContext context) => showDialog<void>(
  context: context,
  barrierColor: ModalUtils.getModalBarrierColor(
    isDark: Theme.of(context).brightness == Brightness.dark,
    context: context,
  ),
  builder: (_) => const FrontChatSurface(),
);

/// Her surface: the whole screen below the page breakpoint, else a panel up
/// to the detail measure, inset from the window; on a desktop-width window
/// her conversations sit beside the one open, as in a ChatGPT or Claude
/// window.
class FrontChatSurface extends StatelessWidget {
  const FrontChatSurface({super.key});

  /// The share of the panel the list beside the conversation takes: room
  /// for a preview that says something, the conversation keeping the rest.
  static const double listShare = 0.38;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final window = MediaQuery.sizeOf(context);
    void close() => Navigator.of(context).pop();
    // The composer's field needs a Material ancestor; the Scaffold also keeps
    // the keyboard inset honest on a phone.
    Widget pane({double? listWidth}) => ModalEscapeScope(
      child: Scaffold(
        body: FrontChatPane(onClose: close, listWidth: listWidth),
      ),
    );

    if (window.width < WoltModalConfig.pageBreakpoint) {
      return Dialog.fullscreen(child: pane());
    }
    final inset = tokens.spacing.step6;
    final width = (window.width - 2 * inset).clamp(0.0, kDetailContentMaxWidth);
    return Dialog(
      insetPadding: EdgeInsets.all(inset),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.m),
      ),
      child: SizedBox(
        width: width,
        height: window.height - 2 * inset,
        child: pane(
          listWidth: isDesktopLayout(context) ? width * listShare : null,
        ),
      ),
    );
  }
}
