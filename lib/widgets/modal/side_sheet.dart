import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/modal/sized_wolt_side_sheet_type.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// The app's side sheet: a right-anchored, full-height panel over the shared
/// scrim on a wide window, and a bottom sheet on a phone.
///
/// This is the host the Daily OS check-in made, extracted so every surface
/// that slides a panel in beside the page reads the same — the page dims,
/// the panel is the front surface, and the page never reflows around it.
/// [sideSheet] sizes the wide panel; [fullHeightOnPhone] makes the phone's
/// bottom sheet take the whole height, for content that needs the room
/// (a conversation, a voice capture) rather than shrink-wrapping.
WoltModalType sideSheetModalType(
  BuildContext context, {
  SizedWoltSideSheetType sideSheet = const SizedWoltSideSheetType(),
  bool fullHeightOnPhone = false,
}) {
  if (MediaQuery.sizeOf(context).width < WoltModalConfig.pageBreakpoint) {
    return fullHeightOnPhone
        ? const WoltBottomSheetType(forceMaxHeight: true)
        : WoltModalType.bottomSheet();
  }
  return sideSheet;
}

/// Opens [builder] as a side sheet that fills it: the content gets the
/// panel's whole bounded box, so it can lay out its own header, a scrolling
/// middle and a pinned footer with `Expanded` — which a scrolling Wolt page,
/// laying content out in a shrink-wrapping viewport, cannot offer.
///
/// The content owns its chrome (no Wolt top bar, close button or drag
/// handle); closing it is `Navigator.pop` on the context it is built with, a
/// tap on the scrim, Esc, or — on a phone — dragging the sheet down.
///
/// The drag handle stays off because Wolt lays it over the page as an opaque
/// hit target the full width of the sheet and 48 px tall: it would swallow
/// every tap on the content's own header, close button included. Drag to
/// dismiss does not need it — Wolt listens for the drag on the whole sheet.
Future<T?> showSideSheetPane<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  SizedWoltSideSheetType sideSheet = const SizedWoltSideSheetType(),
}) {
  return ModalUtils.showWoltModal<T>(
    context: context,
    // The root navigator, always: the desktop tabs each run a nested
    // navigator, and a sheet pushed there would dim only the tab.
    useRootNavigator: true,
    modalTypeBuilder: (modalContext) => sideSheetModalType(
      modalContext,
      sideSheet: sideSheet,
      fullHeightOnPhone: true,
    ),
    showDragHandle: false,
    pageListBuilder: (modalContext) => [
      NonScrollingWoltModalSheetPage(
        backgroundColor: ModalUtils.getModalBackgroundColor(modalContext),
        child: Builder(builder: builder),
      ),
    ],
  );
}

/// The side sheet an agent conversation opens in: a fixed reading width, so
/// a goal's chat and a person's chat are the same panel.
const kAgentChatSideSheet = SizedWoltSideSheetType(
  widthFraction: 1,
  minWidth: kAgentChatSheetWidth,
  maxWidth: kAgentChatSheetWidth,
);
