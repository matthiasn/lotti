import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
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
    final titleM = (0.1 * w).clamp(0.9, 2.0) * (_live ? 1 : 1.35);
    final itemM = (0.22 * titleM).clamp(0.55, 1.2);
    final metaM = (0.15 * titleM).clamp(0.45, 1.0);
    final chipM = (0.12 * titleM).clamp(0.4, 0.9);
    final pad = m(0.08 * w);
    final chip = PlazaStyle.chip(attention);
    final bar = PlazaStyle.lightBar(attention);
    final items = task.openChecklistItems;
    final tickedCount = t?.tickedCount(task.id) ?? 0;
    final total = task.checklistItems;
    final done = task.checklistItems - items.length + tickedCount;
    final pct = task.state == PlazaTaskState.done
        ? 1.0
        : total > 0
        ? done / total
        : task.state == PlazaTaskState.inProgress
        ? 0.35
        : 0.0;
    final metaBits = <String>[
      if (task.due != null) 'due ${shortDate(task.due!)}',
      if (task.linkedTaskIds.isNotEmpty) 'links ${task.linkedTaskIds.length}',
    ];

    return Material(
      color: PlazaStyle.panel,
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
                Container(
                  height: m(0.4),
                  color: PlazaStyle.categoryBright(task),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(pad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: _live && items.isNotEmpty ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: PlazaStyle.fontText,
                            fontWeight: FontWeight.w700,
                            fontSize: m(titleM),
                            height: 1.14,
                            letterSpacing: -m(titleM) * 0.012,
                            color: PlazaStyle.text,
                          ),
                        ),
                        if (_live && metaBits.isNotEmpty) ...[
                          SizedBox(height: m(0.3 * titleM)),
                          Text(
                            metaBits.join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: PlazaStyle.fontText,
                              fontSize: m(metaM),
                              color: PlazaStyle.textMed,
                            ),
                          ),
                        ],
                        if (task.coverImageUrl != null) ...[
                          SizedBox(height: m(0.3 * titleM)),
                          Flexible(
                            flex: 3,
                            child: _Cover(
                              url: task.coverImageUrl!,
                              quiet: attention.lantern == LanternState.off,
                            ),
                          ),
                        ],
                        if (_live && items.isNotEmpty) ...[
                          SizedBox(height: m(0.3 * titleM)),
                          // Only as many items as the wall has room for:
                          // a short building shows fewer, never overflows.
                          Flexible(
                            flex: 4,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Box + padding + the line's own leading.
                                final rowPx = m(itemM) * 1.6;
                                final fit = (constraints.maxHeight / rowPx)
                                    .floor()
                                    .clamp(0, items.length);
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    for (final (i, label)
                                        in items.take(fit).indexed)
                                      _Item(
                                        label: label,
                                        ticked:
                                            t?.isTicked(task.id, i) ?? false,
                                        fontPx: m(itemM),
                                        onTap: t == null
                                            ? null
                                            : () => t.toggle(task.id, i),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            _Chip(
                              label: chip.label,
                              fill: chip.fill,
                              ink: chip.ink,
                              fontPx: m(chipM),
                            ),
                            if (_live && onOpen != null) ...[
                              SizedBox(width: m(0.3)),
                              _Chip(
                                label: 'OPEN',
                                fill: PlazaStyle.teal,
                                ink: const Color(0xFF0D0D0D),
                                fontPx: m(chipM),
                                onTap: onOpen,
                              ),
                            ],
                            const Spacer(),
                            if (_live && total > 0)
                              Text(
                                '$done/$total',
                                style: TextStyle(
                                  fontFamily: PlazaStyle.fontMono,
                                  fontSize: m(metaM),
                                  color: PlazaStyle.textDim,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Progress light bar along the base, readable from any angle.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: m(0.3),
                  decoration: BoxDecoration(
                    color: bar,
                    boxShadow: [BoxShadow(color: bar, blurRadius: m(0.6))],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.url, required this.quiet});

  final String url;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: quiet ? 0.45 : 1,
      child: Image.network(
        url,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const SizedBox(),
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
                  ? Icon(Icons.check, size: box * 0.8, color: PlazaStyle.panel)
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

/// A state chip (or the OPEN button when [onTap] is set).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.fill,
    required this.ink,
    required this.fontPx,
    this.onTap,
  });

  final String label;
  final Color fill;
  final Color ink;
  final double fontPx;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontPx * 0.8,
        vertical: fontPx * 0.25,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(fontPx * 0.35),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: PlazaStyle.fontText,
          fontSize: fontPx,
          fontWeight: FontWeight.w700,
          letterSpacing: fontPx * 0.05,
          color: ink,
        ),
      ),
    );
    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      hoverColor: PlazaStyle.tealHover,
      borderRadius: BorderRadius.circular(fontPx * 0.35),
      child: child,
    );
  }
}
