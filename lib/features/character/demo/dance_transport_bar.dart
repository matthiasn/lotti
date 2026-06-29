import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The dance demo's transport + timeline chrome — the console under the
/// "single large video" stage. Extracted from the demo entrypoint so it can be
/// screenshot-reviewed and unit-tested in isolation, and kept self-contained
/// (no design-system import) so the character feature stays cleanly ejectable —
/// see `character_dance_to_track_demo.dart`'s header. These are demo-only chrome
/// values, not product design tokens.
///
/// The bar is purely presentational: it renders the supplied state and reports
/// intent through callbacks. All playback/seek behavior lives in the page.
class DanceTransportBar extends StatelessWidget {
  const DanceTransportBar({
    required this.loading,
    required this.playing,
    required this.loop,
    required this.showCaptions,
    required this.captionsAvailable,
    required this.useNewBackdrop,
    required this.bpm,
    required this.positionSec,
    required this.durationSec,
    required this.currentSectionLabel,
    required this.amplitudes,
    required this.sections,
    required this.onPlayPause,
    required this.onToggleLoop,
    required this.onToggleCaptions,
    required this.onToggleBackdrop,
    required this.onSeekToSeconds,
    super.key,
  });

  /// True until the beat map has loaded — transport controls rest disabled and
  /// the metadata cluster is hidden.
  final bool loading;
  final bool playing;
  final bool loop;
  final bool showCaptions;

  /// Whether a lyrics file is present — gates the captions toggle.
  final bool captionsAvailable;
  final bool useNewBackdrop;
  final double bpm;
  final double positionSec;
  final double durationSec;
  final String? currentSectionLabel;

  /// Full-track waveform, normalized 0..1. Null while loading; empty when the
  /// beat map carries no waveform.
  final List<double>? amplitudes;
  final List<DanceWaveformSection> sections;

  final VoidCallback onPlayPause;
  final VoidCallback onToggleLoop;
  final VoidCallback onToggleCaptions;
  final VoidCallback onToggleBackdrop;
  final ValueChanged<double> onSeekToSeconds;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_Chrome.panelTop, _Chrome.panelBottom],
        ),
        border: Border(top: BorderSide(color: _Chrome.topEdge)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _transportRow(),
            const SizedBox(height: 12),
            _timeline(),
          ],
        ),
      ),
    );
  }

  Widget _transportRow() {
    // Transport + time read as one left-anchored unit; metadata sits right, with
    // a single intentional gap between them (the full-width timeline below
    // carries the middle) — no hollow centre.
    return Row(
      children: [
        _transportControls(),
        const SizedBox(width: 18),
        _timeGroup(),
        const Spacer(),
        _metaGroup(),
      ],
    );
  }

  Widget _transportControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _playButton(),
        const SizedBox(width: 14),
        _toggleCluster(),
      ],
    );
  }

  Widget _playButton() {
    final enabled = !loading;
    return Tooltip(
      message: playing ? 'Pause (Space)' : 'Play (Space)',
      child: DecoratedBox(
        // A soft TEAL glow lifts the disc cleanly off the panel — no black
        // Material drop-shadow (which muddies into a grey halo on dark).
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: _Chrome.accent.withValues(alpha: 0.42),
                    blurRadius: 14,
                    spreadRadius: -3,
                  ),
                ]
              : null,
        ),
        child: Material(
          color: enabled ? _Chrome.accent : _Chrome.group,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onPlayPause : null,
            child: SizedBox(
              // Larger than the 40px toggle cluster so primacy comes from size,
              // not just colour — the play disc is the single solid-teal element.
              width: 48,
              height: 48,
              child: Icon(
                playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 28,
                color: enabled ? const Color(0xFF06231F) : _Chrome.textLow,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _toggleCluster() {
    return Material(
      color: _Chrome.group,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_Chrome.radius),
        side: const BorderSide(color: _Chrome.groupBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle(
            icon: Icons.repeat_rounded,
            active: loop,
            enabled: !loading,
            tooltip: loop ? 'Looping track' : 'Play once',
            onTap: onToggleLoop,
          ),
          // Captions are hidden entirely when there are no lyrics, so an inert
          // disabled control can never be mistaken for a live one (or vice versa).
          if (captionsAvailable) ...[
            const _VRule(height: 40),
            _toggle(
              icon: showCaptions
                  ? Icons.closed_caption_rounded
                  : Icons.closed_caption_off_rounded,
              active: showCaptions,
              enabled: true,
              tooltip: showCaptions ? 'Hide lyrics' : 'Show lyrics',
              onTap: onToggleCaptions,
            ),
          ],
          const _VRule(height: 40),
          _toggle(
            // A picture glyph (filled = layered scene, outline = flat plate) so
            // it reads as a backdrop swap, not fullscreen/fit.
            icon: useNewBackdrop ? Icons.image_rounded : Icons.image_outlined,
            active: useNewBackdrop,
            enabled: true,
            tooltip: useNewBackdrop ? 'Blue-hour scene' : 'Waterfront plate',
            onTap: onToggleBackdrop,
          ),
        ],
      ),
    );
  }

  Widget _toggle({
    required IconData icon,
    required bool active,
    required bool enabled,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    // Unmistakable on/off: an active cell lights up with a strong teal wash +
    // a white glyph + a thick underline; an inactive cell is a dim glyph on the
    // bare group. The play disc still dominates (solid fill, larger, glow), so
    // a bold active wash here doesn't steal its primacy.
    final color = !enabled
        ? const Color(0xFF3C434D)
        : active
        ? _Chrome.textHi
        : _Chrome.textLow;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 40,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: active && enabled
              ? const BoxDecoration(
                  // The thick underline + bright glyph carry the on-state; the
                  // wash is just a hint, so the solid play disc keeps primacy.
                  color: Color(0x294DD6C0),
                  border: Border(
                    bottom: BorderSide(color: _Chrome.accent, width: 3),
                  ),
                )
              : null,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  /// Left zone: the headline ms timecode + the musical bar.beat position.
  Widget _timeGroup() {
    if (loading) {
      return const Text(
        'loading…',
        style: TextStyle(color: _Chrome.textMid, fontSize: 14),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_timecode(), const SizedBox(width: 14), _barsBeats()],
    );
  }

  /// Right zone: tempo/meter + the now-playing section, de-chipped (no
  /// button-like boxes) so static readouts never look pressable.
  Widget _metaGroup() {
    if (loading) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _bpmMeter(),
        const SizedBox(width: 18),
        const _VRule(height: 28),
        const SizedBox(width: 18),
        _sectionReadout(),
      ],
    );
  }

  /// The musical position (bar.beat, 4/4) beside the ms timecode, so the tempo
  /// grid and the headline time speak the same language instead of clashing.
  Widget _barsBeats() {
    final beatSec = bpm > 0 ? 60.0 / bpm : 0.5;
    final totalBeats = positionSec / beatSec;
    final bar = (totalBeats ~/ 4) + 1;
    final beat = (totalBeats % 4).floor() + 1;
    final sixteenth = ((totalBeats % 1) * 4).floor() + 1;
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(
            text: 'BAR ',
            style: TextStyle(
              color: _Chrome.textLow,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          TextSpan(
            text: '$bar.$beat.$sixteenth',
            style: const TextStyle(
              color: _Chrome.textMid,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timecode() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: formatDancePlaybackTimestamp(positionSec),
            style: const TextStyle(
              color: _Chrome.textHi,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          TextSpan(
            text: '  / ${formatDancePlaybackTimestamp(durationSec)}',
            style: const TextStyle(
              color: _Chrome.textMid,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Tempo + meter, as a plain readout (no button-like chrome).
  Widget _bpmMeter() {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: bpm.toStringAsFixed(0),
            style: const TextStyle(
              color: _Chrome.textHi,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const TextSpan(
            text: ' BPM',
            style: TextStyle(
              color: _Chrome.textLow,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const TextSpan(
            text: '   4/4',
            style: TextStyle(
              color: _Chrome.textLow,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  /// Now-playing section, as a plain readout: a hue dot + the section name. The
  /// energy state isn't labelled here — it's visible in the video stage itself.
  Widget _sectionReadout() {
    final label = currentSectionLabel ?? '–';
    final hue = _sectionHue(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(
          // Uppercase to match the timeline's marker pills (one label system).
          label.toUpperCase(),
          style: const TextStyle(
            color: _Chrome.textHi,
            fontSize: 13,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _timeline() {
    return SizedBox(
      height: 112,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final amps = amplitudes;
          if (loading || amps == null || durationSec <= 0) {
            return _placeholder('loading…');
          }
          if (amps.isEmpty) {
            return _placeholder(
              'no waveform in beat map — regenerate with analyze.py',
            );
          }
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) =>
                  onSeekToSeconds(d.localPosition.dx / width * durationSec),
              onHorizontalDragUpdate: (d) =>
                  onSeekToSeconds(d.localPosition.dx / width * durationSec),
              child: CustomPaint(
                key: const Key('danceTimeline'),
                size: Size(width, constraints.maxHeight),
                painter: _DanceTimelinePainter(
                  amplitudes: amps,
                  sections: sections,
                  trackDurationSec: durationSec,
                  positionSec: positionSec,
                  bpm: bpm,
                  playing: playing,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _placeholder(String text) => Center(
    child: Text(
      text,
      style: const TextStyle(color: _Chrome.textMid, fontSize: 13),
    ),
  );
}

/// A labelled structural span of the track (verse/chorus/…), used to paint the
/// timeline's section bands + markers and the "now playing" chip.
@immutable
class DanceWaveformSection {
  const DanceWaveformSection({
    required this.start,
    required this.end,
    required this.label,
  });

  final double start;
  final double end;
  final String label;
}

/// Formats a playback position like a video editor transport display.
///
/// Tracks under an hour use `mm:ss.mmm`; longer tracks use `h:mm:ss.mmm`.
String formatDancePlaybackTimestamp(double seconds) {
  final safeSeconds = seconds.isFinite && seconds > 0 ? seconds : 0.0;
  final totalMillis = (safeSeconds * 1000).round();
  final wholeSeconds = totalMillis ~/ 1000;
  final millis = totalMillis % 1000;
  final hours = wholeSeconds ~/ 3600;
  final minutes = (wholeSeconds % 3600) ~/ 60;
  final secs = wholeSeconds % 60;
  final millisText = millis.toString().padLeft(3, '0');
  final secText = secs.toString().padLeft(2, '0');
  final minText = minutes.toString().padLeft(2, '0');
  if (hours > 0) return '$hours:$minText:$secText.$millisText';
  return '$minText:$secText.$millisText';
}

/// A thin hairline vertical rule used between the metadata readouts.
class _VRule extends StatelessWidget {
  const _VRule({this.height = 26});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    height: height,
    child: const ColoredBox(color: _Chrome.hairline),
  );
}

/// Self-contained dark "console" palette for the transport chrome. Demo-only —
/// not product design tokens (see [DanceTransportBar]'s doc).
abstract final class _Chrome {
  /// The single interactive accent (play, active toggles, playhead handle).
  static const Color accent = Color(0xFF4DD6C0);
  static const Color panelTop = Color(0xFF1B2127);
  static const Color panelBottom = Color(0xFF0F1216);
  static const Color group = Color(0xFF222A33);
  static const Color groupBorder = Color(0x14FFFFFF);
  static const Color hairline = Color(0x1AFFFFFF);
  static const Color topEdge = Color(0x1FFFFFFF);
  static const Color textHi = Color(0xFFEDF1F5);
  static const Color textMid = Color(0xFF8A96A3);
  static const Color textLow = Color(0xFF59626D);
  static const double radius = 10;

  // Two-tone waveform (the neutral cool DATA layer, never the teal accent): a
  // dim PEAK outline + a brighter RMS body, drawn symmetrically, so real
  // dynamics read instead of a uniform sausage. Played is bright; ahead is
  // clearly dimmer so progress reads from the waveform itself, not only the
  // playhead.
  static const Color wavePeakPlayed = Color(0xFF7E93A6);
  static const Color waveBodyPlayed = Color(0xFFC9DEEE);
  static const Color wavePeakAhead = Color(0xFF525C68);
  static const Color waveBodyAhead = Color(0xFF808E9C);
  static const Color rulerText = Color(0xFF7C8896);
  static const Color markerPill = Color(0xD90B0F14);
}

/// The structural hue for a section label. Recurring labels share a colour, so
/// the timeline bands and the "now playing" chip read as the same clip.
Color _sectionHue(String label) {
  // A sober, low-chroma clip palette — colour-codes structure (recurring
  // sections share a hue) WITHOUT a candy rainbow that fights the teal accent or
  // the cool data waveform. Keyed by musical section name, with the structural
  // A–F letters as a fallback.
  final k = label.toLowerCase();
  if (k.contains('chorus')) {
    if (k.startsWith('pre')) return const Color(0xFFC7A86A); // pre → amber
    if (k.startsWith('post')) return const Color(0xFFC089A0); // post → rose
    return const Color(0xFFCB8B77); // chorus → terracotta (the hook)
  }
  if (k.contains('verse')) return const Color(0xFF7E97B2); // steel-blue
  if (k.contains('bridge')) return const Color(0xFF9A86BE); // violet
  if (k.contains('intro') || k.contains('outro')) {
    return const Color(0xFF8893A0); // slate
  }
  const letters = <String, Color>{
    'a': Color(0xFFCB8B77),
    'b': Color(0xFF7E97B2),
    'c': Color(0xFFC7A86A),
    'd': Color(0xFF9A86BE),
    'e': Color(0xFF7FB293),
    'f': Color(0xFFC089A0),
  };
  return letters[k] ?? const Color(0xFF8893A0);
}

/// Paints the full-track timeline: faint section bands + markers, a filled
/// mirrored waveform split played/ahead at the playhead, and a crisp playhead
/// with a handle — the seek surface under the stage.
class _DanceTimelinePainter extends CustomPainter {
  _DanceTimelinePainter({
    required this.amplitudes,
    required this.sections,
    required this.trackDurationSec,
    required this.positionSec,
    required this.bpm,
    required this.playing,
  });

  final List<double> amplitudes;
  final List<DanceWaveformSection> sections;
  final double trackDurationSec;
  final double positionSec;
  final double bpm;
  final bool playing;

  static const double _rulerH = 14; // time ruler: ticks + m:ss labels
  static const double _markerH = 13; // section rehearsal-mark pills
  static const double _headerH = _rulerH + _markerH;

  double _x(double t, double width) =>
      (t / trackDurationSec * width).clamp(0.0, width);

  @override
  void paint(Canvas canvas, Size size) {
    if (amplitudes.isEmpty || trackDurationSec <= 0) return;
    final px = (positionSec / trackDurationSec * size.width).clamp(
      0.0,
      size.width,
    );
    const waveTop = _headerH;
    final waveBottom = size.height;
    final mid = (waveTop + waveBottom) / 2;

    _paintSectionBands(canvas, size, waveTop);
    _paintBaseline(canvas, size, mid);
    _paintWaveform(
      canvas,
      size,
      waveTop: waveTop,
      waveBottom: waveBottom,
      mid: mid,
      px: px,
    );
    // The grid overlays the waveform so the downbeats actually read through it.
    _paintBeatGrid(canvas, size, waveTop);
    _paintRuler(canvas, size);
    _paintMarkers(canvas, size);
    _paintPlayhead(canvas, size, px);
  }

  void _paintSectionBands(Canvas canvas, Size size, double waveTop) {
    for (final s in sections) {
      final sx0 = _x(s.start, size.width);
      final sx1 = _x(s.end, size.width);
      final active = positionSec >= s.start && positionSec < s.end;
      final hue = _sectionHue(s.label);
      // Boundary line spanning the full height (ties marker → header → wave).
      canvas.drawRect(
        Rect.fromLTWH(sx0, 0, 1, size.height),
        Paint()..color = const Color(0x1FFFFFFF),
      );
      if (active) {
        // The live region: a colored clip top-edge + a neutral cool wash. The
        // filled marker pill finishes the "you are here" read — no heavy hue box
        // (the old full side+top frame read like a loop region on the wrong cue).
        canvas
          ..drawRect(
            Rect.fromLTRB(sx0, waveTop, sx1, waveTop + 4),
            Paint()..color = hue.withValues(alpha: 0.95),
          )
          ..drawRect(
            Rect.fromLTRB(sx0, waveTop + 4, sx1, size.height),
            Paint()..color = const Color(0x12FFFFFF),
          );
      }
    }
  }

  /// A faint bar grid derived from the displayed tempo (4/4) — the DAW "beat
  /// grid" reference for a beat-sync tool. Every 4th bar (a phrase) is brighter.
  void _paintBeatGrid(Canvas canvas, Size size, double waveTop) {
    if (bpm <= 0) return;
    final barSec = 60.0 / bpm * 4;
    if (barSec <= 0) return;
    // t = barSec is the start of bar 2; `bar` is the bar number at that line.
    var bar = 2;
    for (var t = barSec; t < trackDurationSec; t += barSec, bar++) {
      final x = _x(t, size.width);
      if ((bar - 1) % 4 == 0) {
        // Phrase downbeats run the FULL height — clearly legible in the header
        // (no waveform to hide them) — the beat-grid reference a sync tool needs.
        canvas.drawRect(
          Rect.fromLTWH(x, 0, 1, size.height),
          Paint()..color = const Color(0x5CFFFFFF),
        );
      } else {
        // Bar lines stay a faint texture inside the wave lane.
        canvas.drawRect(
          Rect.fromLTWH(x, waveTop, 1, size.height - waveTop),
          Paint()..color = const Color(0x0AFFFFFF),
        );
      }
    }
  }

  void _paintBaseline(Canvas canvas, Size size, double mid) {
    canvas.drawRect(
      Rect.fromLTWH(0, mid - 0.5, size.width, 1),
      Paint()..color = const Color(0x0DFFFFFF),
    );
  }

  void _paintWaveform(
    Canvas canvas,
    Size size, {
    required double waveTop,
    required double waveBottom,
    required double mid,
    required double px,
  }) {
    final n = amplitudes.length;
    final maxH = (waveBottom - waveTop) - 6;
    // Symmetric two-tone sample bars: a dim PEAK outline with a brighter RMS
    // body inside, expanded (pow > 1) so loud/quiet actually differ instead of
    // reading as a uniform sausage. Played bright, ahead dim — so playback
    // progress reads from the waveform itself, not only the playhead.
    const pitch = 3.0;
    const barW = 2.0;
    final cols = math.max(1, size.width ~/ pitch);
    for (var c = 0; c < cols; c++) {
      final x = c * pitch;
      final i0 = (c * n) ~/ cols;
      final i1 = math.max(i0 + 1, ((c + 1) * n) ~/ cols);
      var peak = 0.0;
      var sum = 0.0;
      var cnt = 0;
      for (var i = i0; i < i1 && i < n; i++) {
        final v = amplitudes[i];
        if (v > peak) peak = v;
        sum += v;
        cnt++;
      }
      final rms = cnt > 0 ? sum / cnt : peak;
      final peakH = (math.pow(peak, 1.95) * maxH).clamp(2, maxH).toDouble();
      final bodyH = (math.pow(rms, 1.95) * maxH).clamp(1, peakH).toDouble();
      final past = x + barW <= px;
      canvas
        ..drawRect(
          Rect.fromLTWH(x, mid - peakH / 2, barW, peakH),
          Paint()
            ..color = past ? _Chrome.wavePeakPlayed : _Chrome.wavePeakAhead,
        )
        ..drawRect(
          Rect.fromLTWH(x, mid - bodyH / 2, barW, bodyH),
          Paint()
            ..color = past ? _Chrome.waveBodyPlayed : _Chrome.waveBodyAhead,
        );
    }
  }

  /// The time ruler: ticks + `m:ss` labels at a tempo-independent nice interval.
  void _paintRuler(Canvas canvas, Size size) {
    final interval = _rulerInterval(trackDurationSec);
    if (interval <= 0) return;
    final tick = Paint()..color = const Color(0x33FFFFFF);
    for (var t = 0.0; t < trackDurationSec - interval * 0.25; t += interval) {
      final x = _x(t, size.width);
      canvas.drawRect(Rect.fromLTWH(x, 0, 1, 4), tick);
      (TextPainter(
        text: TextSpan(
          text: _mmss(t),
          style: const TextStyle(
            fontFamily: 'Inter',
            color: _Chrome.rulerText,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout()).paint(canvas, Offset(x + 3, 2.5));
    }
  }

  /// Section rehearsal-mark pills with collision handling: consecutive identical
  /// labels collapse, and a pill is skipped when it would crowd the previous one
  /// — so dense heads stop piling up into an illegible "A B C B B".
  void _paintMarkers(Canvas canvas, Size size) {
    var lastRight = -1e9;
    String? prevLabel;
    for (final s in sections) {
      final sx0 = _x(s.start, size.width);
      final active = positionSec >= s.start && positionSec < s.end;
      final hue = _sectionHue(s.label);
      final collapsed = s.label == prevLabel;
      prevLabel = s.label;
      if (collapsed) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: s.label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            color: active
                ? const Color(0xFF0B0F14)
                : hue.withValues(alpha: 0.92),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pillW = tp.width + 9;
      const pillH = _markerH - 1.0;
      if (sx0 < lastRight + 5) continue;
      final left = sx0 + 1;
      const top = _rulerH + 0.5;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, pillW, pillH),
        const Radius.circular(3),
      );
      if (active) {
        canvas.drawRRect(rrect, Paint()..color = hue);
      } else {
        // A faint hue-tinted dark pill so the marks group by colour at a glance
        // instead of reading as monochrome letter-soup.
        canvas
          ..drawRRect(rrect, Paint()..color = _Chrome.markerPill)
          ..drawRRect(rrect, Paint()..color = hue.withValues(alpha: 0.20))
          ..drawRRect(
            rrect,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = hue.withValues(alpha: 0.55),
          );
      }
      tp.paint(
        canvas,
        Offset(left + (pillW - tp.width) / 2, top + (pillH - tp.height) / 2),
      );
      lastRight = left + pillW;
    }
  }

  void _paintPlayhead(Canvas canvas, Size size, double px) {
    canvas
      // Soft teal glow flanking the line, below the ruler.
      ..drawRect(
        Rect.fromLTWH(px - 2, _rulerH, 4, size.height - _rulerH),
        Paint()..color = const Color(0x2E4DD6C0),
      )
      // A dark casing so the teal line stays legible even over bright peaks…
      ..drawRect(
        Rect.fromLTWH(px - 1.5, 0, 3, size.height),
        Paint()..color = const Color(0x59041C18),
      )
      // …then the crisp teal line — one accent for the whole playhead element.
      ..drawRect(
        Rect.fromLTWH(px - 0.75, 0, 1.5, size.height),
        Paint()..color = _Chrome.accent,
      );
    // A downward "flag" marker at the top (flat top, point at the bottom) — the
    // classic editor playhead, unmistakably a position marker rather than the
    // pause-glyph the old twin grip-bars read as.
    final flag = Path()
      ..moveTo(px - 6, 0)
      ..lineTo(px + 6, 0)
      ..lineTo(px + 6, 9)
      ..lineTo(px, 14)
      ..lineTo(px - 6, 9)
      ..close();
    canvas
      ..drawPath(
        flag.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawPath(
        flag,
        Paint()
          ..isAntiAlias = true
          ..color = _Chrome.accent,
      );
  }

  /// A "nice" ruler step (s) giving roughly 5–8 labels across the track.
  static double _rulerInterval(double dur) {
    const candidates = <double>[10, 15, 20, 30, 60, 120, 300];
    for (final c in candidates) {
      if (dur / c <= 8) return c;
    }
    return 300;
  }

  static String _mmss(double s) {
    final t = s.round();
    final m = t ~/ 60;
    final ss = (t % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  bool shouldRepaint(_DanceTimelinePainter old) =>
      old.positionSec != positionSec ||
      old.playing != playing ||
      old.bpm != bpm ||
      old.trackDurationSec != trackDurationSec ||
      !identical(old.amplitudes, amplitudes) ||
      !identical(old.sections, sections);
}
