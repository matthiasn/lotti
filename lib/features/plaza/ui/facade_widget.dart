import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/cover_image.dart';
import 'package:lotti/features/plaza/ui/plaza_chip.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// Which range a facade is drawn for.
enum FacadeVariant {
  /// Street range, captured: category bar, big title, cover art, state
  /// chip, light bar. Nothing that cannot be read at 100 m.
  sign,

  /// Shopfront range, live: everything, with working checkboxes and OPEN.
  live,
}

/// The signage on one building's street-facing wall.
///
/// Laid out in world metres scaled by [pxPerMeter], so the type reads the
/// same on a 5 m shop and a 15 m tower: the title is roughly a tenth of the
/// wall's width tall, the interactive strip sits at the bottom where a 2.2 m
/// walker looks, and the progress light bar runs along the base.
class FacadeWidget extends StatelessWidget {
  const FacadeWidget({
    required this.task,
    required this.attention,
    required this.variant,
    required this.widthMeters,
    required this.pxPerMeter,
    this.ticks,
    this.onOpen,
    this.onCoverChanged,
    this.focused = false,
    super.key,
  });

  final PlazaTask task;
  final TaskAttention attention;
  final FacadeVariant variant;

  /// Facade width in world metres; every size derives from it.
  final double widthMeters;
  final double pxPerMeter;

  /// Shared tick state; required for the live variant to be interactive.
  final ChecklistTicks? ticks;
  final VoidCallback? onOpen;

  /// Invalidates a hosted texture once asynchronous cover loading settles.
  final VoidCallback? onCoverChanged;

  /// Draws the teal focus ring (the faced building is the live one).
  final bool focused;

  bool get _live => variant == FacadeVariant.live;

  @override
  Widget build(BuildContext context) {
    final t = ticks;
    if (t == null) return _build(context, null);
    return ListenableBuilder(
      listenable: t,
      builder: (context, _) => _build(context, t),
    );
  }

  Widget _build(BuildContext context, ChecklistTicks? t) {
    double m(double meters) => meters * pxPerMeter;
    final w = widthMeters;
    var titleM = (0.1 * w).clamp(0.9, 2.0) * (_live ? 1 : 1.35);
    // Never break a word in the middle of a wall: shrink the title until
    // its longest word fits the measure.
    final innerPx = (w - 2 * 0.08 * w) * pxPerMeter;
    final longest = task.title
        .split(RegExp(r'\s+'))
        .fold<int>(0, (n, word) => math.max(n, word.length));
    while (titleM > 0.55 && longest * m(titleM) * 0.6 > innerPx) {
      titleM *= 0.9;
    }
    final itemM = (0.22 * titleM).clamp(0.55, 1.2);
    final metaM = (0.15 * titleM).clamp(0.45, 1.0);
    final chipM = (0.14 * titleM).clamp(0.5, 1.1);
    final pad = m(0.08 * w);
    final chip = PlazaStyle.chip(attention);
    final items = task.openChecklistItems;
    final tickedCount = t?.tickedCount(task.id) ?? 0;
    final total = task.checklistItems;
    final done = task.checklistItems - items.length + tickedCount;
    final metaBits = taskMetaBits(task);

    // A finished shop is dark: everything on it steps down.
    final quiet = attention.lantern == LanternState.off;
    final ink = quiet ? PlazaStyle.textDim : PlazaStyle.text;
    // A live wall is a lit screen, not a hole: the panel takes a little
    // of the state colour; a finished shop is dark but not unrendered.
    return Material(
      color: quiet
          ? const Color(0xFF0E0D16)
          : _live
          ? Color.lerp(
              PlazaStyle.panel,
              PlazaStyle.lantern(attention.lantern),
              0.12,
            )!
          : PlazaStyle.panel,
      child: Container(
        foregroundDecoration: focused
            ? BoxDecoration(
                border: Border.all(color: PlazaStyle.teal, width: m(0.12)),
              )
            : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The category band belongs to the sign tier; a live wall
                // has the state rim and the focus ring for its frame.
                if (!_live)
                  Container(
                    height: m(0.4),
                    color: quiet
                        ? Color.lerp(
                            PlazaStyle.categoryBright(task),
                            const Color(0xFF07060B),
                            0.6,
                          )
                        : PlazaStyle.categoryBright(task),
                  ),
                if (!_live)
                  // Street range: the state is a marquee band at the top,
                  // where the street cannot hide it, with its glyph.
                  Container(
                    padding: EdgeInsets.symmetric(vertical: m(chipM) * 0.4),
                    color: chip.fill,
                    child: Text(
                      '${PlazaStyle.glyph(attention)}  ${chip.label}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: PlazaStyle.fontText,
                        fontSize: m(chipM * 1.5),
                        fontWeight: FontWeight.w800,
                        letterSpacing: m(chipM) * 0.12,
                        color: chip.ink,
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // A squat wall keeps the title and the chips;
                        // meta, cover and checklist yield. The title has
                        // a bounded box and scales down inside it, so no
                        // wall ever overflows.
                        final tight = box.maxHeight < m(6);
                        final gap = math.min(
                          m(0.3 * titleM),
                          box.maxHeight * 0.04,
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // A finished task is a small sign: the wall-height
                            // title is for what is live or wrong.
                            // A live wall with a checklist gives the list
                            // its row: the title scales down before the
                            // list loses its last item.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    box.maxHeight *
                                    (tight
                                        ? 0.5
                                        : _live && items.isNotEmpty
                                        ? 0.4
                                        : 0.6),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: box.maxWidth,
                                  child: Text(
                                    task.title,
                                    // A live wall with a list keeps the
                                    // title to two lines; the list is what
                                    // you flew here to tick.
                                    maxLines:
                                        quiet || (_live && items.isNotEmpty)
                                        ? 2
                                        : 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: PlazaStyle.fontText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: m(
                                        quiet ? titleM * 0.55 : titleM,
                                      ),
                                      height: 1.14,
                                      letterSpacing: -m(titleM) * 0.012,
                                      color: ink,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (_live &&
                                attention.reason.isNotEmpty &&
                                !tight) ...[
                              SizedBox(height: gap),
                              // The wall you fly to says what the billboard
                              // said, as loudly: the reason leads, in the
                              // state colour.
                              Text(
                                attention.reason,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: PlazaStyle.fontMono,
                                  fontSize: m(itemM),
                                  fontWeight: FontWeight.w500,
                                  color: PlazaStyle.lantern(attention.lantern),
                                ),
                              ),
                            ],
                            if (task.coverImageUrl != null && !tight) ...[
                              SizedBox(height: gap),
                              // The picture gets the biggest band the wall can
                              // spare, edge to edge, but never more than a
                              // third of a live wall: the checklist keeps
                              // its rows.
                              Flexible(
                                flex: _live ? 5 : 10,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: _live
                                        ? box.maxHeight * 0.26
                                        : double.infinity,
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: CoverImage(
                                      url: task.coverImageUrl!,
                                      onLoaded: onCoverChanged,
                                      opacity:
                                          attention.lantern == LanternState.off
                                          ? 0.45
                                          : 1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (_live && items.isNotEmpty && !tight) ...[
                              SizedBox(height: gap),
                              // Only as many items as the wall has room for:
                              // a short building shows fewer, never overflows.
                              // The list outranks the picture for space.
                              Flexible(
                                flex: 6,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Box + padding + the line's own leading,
                                    // counted generously: a row that would not
                                    // fit is dropped, and the list is clipped
                                    // as the backstop, so the wall never shows
                                    // an overflow.
                                    final rowPx = m(itemM) * 1.85;
                                    final fit = (constraints.maxHeight / rowPx)
                                        .floor()
                                        .clamp(0, items.length);
                                    return SingleChildScrollView(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          for (final (i, label)
                                              in items.take(fit).indexed)
                                            _Item(
                                              label: label,
                                              ticked:
                                                  t?.isTicked(task.id, i) ??
                                                  false,
                                              fontPx: m(itemM),
                                              onTap: t == null
                                                  ? null
                                                  : () => t.toggle(task.id, i),
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (_live)
                              // A firm band, never squeezed: the checklist
                              // above yields, the chips keep their size.
                              SizedBox(
                                height: m(chipM) * 2.4,
                                child: LayoutBuilder(
                                  builder: (context, row) => FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.bottomLeft,
                                    child: SizedBox(
                                      width: row.maxWidth,
                                      child: Row(
                                        children: [
                                          // Chips scale down together on a narrow
                                          // wall rather than overflowing the row.
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerLeft,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  PlazaChip(
                                                    label:
                                                        '${PlazaStyle.glyph(attention)} '
                                                        '${chip.label}',
                                                    fill: chip.fill,
                                                    ink: chip.ink,
                                                    fontPx: m(chipM),
                                                  ),
                                                  if (onOpen != null) ...[
                                                    SizedBox(width: m(0.3)),
                                                    PlazaChip(
                                                      label: 'DETAILS ›',
                                                      fill: PlazaStyle.teal,
                                                      ink: const Color(
                                                        0xFF0D0D0D,
                                                      ),
                                                      fontPx: m(chipM),
                                                      onTap: onOpen,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (total > 0) ...[
                                            SizedBox(width: m(0.3)),
                                            Text(
                                              '$done/$total',
                                              style: TextStyle(
                                                fontFamily: PlazaStyle.fontMono,
                                                fontSize: m(metaM),
                                                color: PlazaStyle.textDim,
                                              ),
                                            ),
                                          ],
                                          if (metaBits.isNotEmpty) ...[
                                            SizedBox(width: m(0.4)),
                                            Flexible(
                                              child: Text(
                                                metaBits.join('  ·  '),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontFamily:
                                                      PlazaStyle.fontMono,
                                                  fontSize: m(metaM),
                                                  color: quiet
                                                      ? PlazaStyle.textDim
                                                      : PlazaStyle.textMed,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.ticked,
    required this.fontPx,
    required this.onTap,
  });

  final String label;
  final bool ticked;
  final double fontPx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = fontPx * 1.05;
    return InkWell(
      onTap: onTap,
      hoverColor: PlazaStyle.hoverWash,
      borderRadius: BorderRadius.circular(fontPx * 0.25),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: fontPx * 0.18,
          horizontal: fontPx * 0.15,
        ),
        child: Row(
          children: [
            Container(
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: ticked ? const Color(0xD9FFFFFF) : Colors.transparent,
                border: Border.all(
                  color: const Color(0xBFFFFFFF),
                  width: fontPx * 0.08,
                ),
                borderRadius: BorderRadius.circular(fontPx * 0.12),
              ),
              child: ticked
                  ? Icon(
                      LottiIcons.confirm,
                      size: box * 0.8,
                      color: PlazaStyle.panel,
                    )
                  : null,
            ),
            SizedBox(width: fontPx * 0.4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: PlazaStyle.fontText,
                  fontSize: fontPx,
                  color: ticked ? PlazaStyle.textDim : const Color(0xD9FFFFFF),
                  decoration: ticked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
