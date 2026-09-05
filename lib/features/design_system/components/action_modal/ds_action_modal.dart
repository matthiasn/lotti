import 'package:lotti/features/design_system/components/action_modal/ds_action_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/modal/index.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// The shell shared by the app's action modals — the entry `•••` menu and the
/// "Add" sheet.
///
/// Both used to be assembled by hand out of `ModalUtils` defaults, and the
/// results diverged: one centred its title over a hairline top bar and stacked
/// full-width dividers between plain rows, the other ran teal glyphs and
/// two-line rows with no tiles. One tap apart, they read as two products.
///
/// This class owns the parts that must not drift again — the left-aligned
/// heading with its own trailing close, the body inset, and the 4pt row
/// rhythm — and leaves the rows themselves to the caller, because *what* the
/// two sheets offer is genuinely different.
///
/// The Wolt top-bar *layer* is deliberately off — it draws a background and a
/// centred title, and a title centred inside a [NavigationToolbar] whose
/// leading width mirrors the trailing close button can never reach the sheet's
/// own gutter. The header below rides the toolbar's leading slot instead,
/// full width and owning its own close: that puts the title on the same rail
/// as every row under it while keeping it *above* the bottom sheet's 48pt
/// drag strip, which is opaque and would otherwise eat every tap in the top
/// of the content.
abstract final class DsActionModal {
  /// Presents an action modal: a bottom sheet on narrow layouts, a centred
  /// dialog on wide ones, per the app's single modal breakpoint.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext) builder,
  }) {
    return ModalUtils.showSinglePageModal<T>(
      context: context,
      hasTopBarLayer: false,
      showCloseButton: false,
      navBarHeight: headerHeight(context),
      leadingNavBarWidget: DsActionModalHeader(title: title),
      padding: bodyPadding(context),
      builder: builder,
    );
  }

  /// One page of a multi-page action modal, headed like [show]'s single page.
  ///
  /// [onTapBack] turns the header's leading edge into a back affordance, for
  /// a page reached from the list rather than opened directly.
  static WoltModalSheetPage page({
    required BuildContext context,
    required String title,
    required Widget Function(BuildContext) builder,
    VoidCallback? onTapBack,
  }) {
    return ModalUtils.modalSheetPage(
      context: context,
      hasTopBarLayer: false,
      navBarHeight: headerHeight(context),
      leadingNavBarWidget: DsActionModalHeader(
        title: title,
        onTapBack: onTapBack,
      ),
      padding: bodyPadding(context),
      child: Builder(builder: builder),
    );
  }

  /// The header's height, spelled out as its parts — the heading's own line
  /// box between the header's paddings — rather than pinned to a number that
  /// would stop matching the text the moment the type scale moved.
  ///
  /// It doubles as the toolbar height Wolt reserves above the content, so the
  /// two can never disagree about where the rows start.
  static double headerHeight(BuildContext context) {
    final tokens = _tokens(context);
    return tokens.spacing.step5 +
        tokens.typography.lineHeight.heading3 +
        tokens.spacing.step4;
  }

  static DsTokens _tokens(BuildContext context) =>
      Theme.of(context).extension<DsTokens>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? dsTokensDark
          : dsTokensLight);

  /// The inset around an action modal's rows.
  ///
  /// Tighter at the top than the sides because the header directly above
  /// already spends its own bottom padding on that gap, and short of the side
  /// inset at the foot by the 4pt every [DsActionRow] carries below itself —
  /// so the sheet's bottom edge measures the same 16pt as its sides.
  static EdgeInsets bodyPadding(BuildContext context) {
    final spacing = _tokens(context).spacing;
    return EdgeInsets.fromLTRB(
      spacing.step5,
      spacing.step2,
      spacing.step5,
      spacing.step4,
    );
  }
}

/// An action modal's heading: the title on the sheet's own gutter, with a
/// quiet circular close on the trailing edge and no rule beneath it.
///
/// The divider that used to sit here drew a line the content did not need —
/// the header is already set apart by size and weight, and the rule only
/// competed with the one divider that carries meaning, above the destructive
/// row.
class DsActionModalHeader extends StatelessWidget {
  const DsActionModalHeader({required this.title, this.onTapBack, super.key});

  final String title;

  /// When set, a back affordance leads the header instead of the title
  /// sitting flush on the gutter — the page was pushed from the list.
  final VoidCallback? onTapBack;

  /// Diameter of a header affordance's hover target. Smaller than
  /// [TapTargets.minimum] because it rides a header only a little taller than
  /// a row's [ControlSizes.iconChip] tile, and the sheet has two other ways
  /// out besides the close glyph — the scrim and Esc.
  static const double headerButtonSize = 32;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: double.infinity,
      height: DsActionModal.headerHeight(context),
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      alignment: Alignment.center,
      child: Row(
        children: [
          if (onTapBack case final onTapBack?) ...[
            _HeaderIconButton(
              icon: LottiIcons.back,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: onTapBack,
            ),
            SizedBox(width: tokens.spacing.step3),
          ],
          Expanded(
            child: Semantics(
              container: true,
              explicitChildNodes: true,
              header: true,
              namesRoute: true,
              scopesRoute: true,
              label: title,
              child: ExcludeSemantics(
                child: Text(
                  title,
                  style: ModalUtils.modalTitleStyle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          SizedBox(width: tokens.spacing.step4),
          _HeaderIconButton(
            icon: LottiIcons.close,
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// A header affordance: a quiet glyph in a circular hover target.
class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          hoverColor: tokens.colors.surface.hover,
          child: SizedBox(
            width: DsActionModalHeader.headerButtonSize,
            height: DsActionModalHeader.headerButtonSize,
            child: Icon(
              icon,
              size: IconSizes.m,
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Stacks an action modal's rows, with a single rule above the trailing
/// destructive row.
///
/// The rows' own 4pt gaps replace the hairline that used to run between every
/// one of them: with a rounded hover wash the rule became a line *through* the
/// highlight, and the sheet needed a whole hover-index mechanism to fade the
/// pair bracketing the pointer. Separation by whitespace has no such problem,
/// and it leaves the one divider that survives — [destructive] — carrying real
/// weight.
///
/// The list adds no spacing of its own, because a [children] entry that does
/// not apply to this entry renders nothing at all: a gap owned here would
/// still be spent on it.
class DsActionModalList extends StatelessWidget {
  const DsActionModalList({
    required this.children,
    this.header,
    this.destructive,
    super.key,
  });

  /// Content above the rows, set apart by its own bottom padding — the
  /// toggle-chip row on the entry `•••` menu.
  final Widget? header;

  final List<Widget> children;

  /// The single irreversible row, pinned below a divider at the foot of the
  /// list. Null where the sheet has none.
  final Widget? destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header case final header?)
          Padding(
            padding: EdgeInsets.only(bottom: tokens.spacing.step3),
            child: header,
          ),
        ...children,
        if (destructive case final destructive?) ...[
          Padding(
            padding: EdgeInsets.only(
              top: tokens.spacing.step2,
              bottom: tokens.spacing.step3,
              left: tokens.spacing.step2,
              right: tokens.spacing.step2,
            ),
            child: SizedBox(
              height: BorderWidths.hairline,
              child: ColoredBox(color: tokens.colors.decorative.level01),
            ),
          ),
          destructive,
        ],
      ],
    );
  }
}
