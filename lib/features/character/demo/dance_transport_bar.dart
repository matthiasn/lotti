import 'dart:ui' as ui;

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
    required this.currentSectionEnergetic,
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
  final bool currentSectionEnergetic;

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
    return Row(
      children: [
        _playButton(),
        const SizedBox(width: 14),
        _toggleCluster(),
        // Headline timecode, centred so the transport reads as one console
        // instead of two islands across a dead gap.
        Expanded(child: Center(child: _timecode())),
        if (!loading) ...[
          _bpmPill(),
          const SizedBox(width: 8),
          _sectionChip(),
        ],
      ],
    );
  }

  Widget _playButton() {
    final enabled = !loading;
    return Tooltip(
      message: playing ? 'Pause (Space)' : 'Play (Space)',
      child: Material(
        color: enabled ? _Chrome.accent : _Chrome.group,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPlayPause : null,
          child: SizedBox(
            width: 46,
            height: 46,
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 28,
              color: enabled ? const Color(0xFF06231F) : _Chrome.textLow,
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
          const _VRule(height: 38, color: _Chrome.groupBorder),
          _toggle(
            icon: showCaptions
                ? Icons.closed_caption_rounded
                : Icons.closed_caption_off_rounded,
            active: showCaptions && captionsAvailable,
            enabled: captionsAvailable,
            tooltip: showCaptions ? 'Hide lyrics' : 'Show lyrics',
            onTap: onToggleCaptions,
          ),
          const _VRule(height: 38, color: _Chrome.groupBorder),
          _toggle(
            // A backdrop-swap glyph, not a moon (which reads as dark-mode).
            icon: useNewBackdrop
                ? Icons.wallpaper_rounded
                : Icons.image_outlined,
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
    final color = !enabled
        ? _Chrome.textLow
        : active
        ? _Chrome.accent
        : _Chrome.textMid;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          color: active && enabled ? _Chrome.accentSoft : null,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  Widget _timecode() {
    if (loading) {
      return const Text(
        'loading…',
        style: TextStyle(color: _Chrome.textMid, fontSize: 14),
      );
    }
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
              color: _Chrome.textLow,
              fontSize: 14,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bpmPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _Chrome.group,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Chrome.groupBorder),
      ),
      child: Text.rich(
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
          ],
        ),
      ),
    );
  }

  Widget _sectionChip() {
    final label = currentSectionLabel ?? '–';
    final hue = _sectionHue(label);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
      decoration: BoxDecoration(
        color: _Chrome.group,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _Chrome.groupBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: hue, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: _Chrome.textHi,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            currentSectionEnergetic ? 'DANCE' : 'CALM',
            style: TextStyle(
              color: currentSectionEnergetic ? _Chrome.accent : _Chrome.textLow,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
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

/// A thin vertical rule used between control groups and inside the toggle
/// cluster.
class _VRule extends StatelessWidget {
  const _VRule({this.height = 26, this.color = _Chrome.hairline});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 1,
    height: height,
    child: ColoredBox(color: color),
  );
}

/// Self-contained dark "console" palette for the transport chrome. Demo-only —
/// not product design tokens (see [DanceTransportBar]'s doc).
abstract final class _Chrome {
  /// The single interactive accent (play, active toggles, playhead handle).
  static const Color accent = Color(0xFF4DD6C0);
  static const Color accentSoft = Color(0x224DD6C0);
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

  // Waveform = the neutral cool DATA layer, deliberately NOT the teal accent so
  // "interactive" stays uniquely teal. Monotonic top→bottom shade (never
  // centre-bright, which would fake amplitude).
  static const Color wavePlayedTop = Color(0xFFB4CDDE);
  static const Color wavePlayedBot = Color(0xFF6B8398);
  static const Color waveCap = Color(0xFFD6E8F4);
  static const Color waveAhead = Color(0xFF5A6772);
  static const Color rulerText = Color(0xFF727E8A);
  static const Color markerPill = Color(0xD90B0F14);
}

/// The structural hue for a section label. Recurring labels share a colour, so
/// the timeline bands and the "now playing" chip read as the same clip.
Color _sectionHue(String label) {
  // Distinct per-section hues for the rehearsal marks — deliberately NO teal, so
  // the structural colour-coding never collides with the interactive accent.
  const palette = <String, Color>{
    'A': Color(0xFFFF8A8A),
    'B': Color(0xFF7AA2F0),
    'C': Color(0xFFFFCE73),
    'D': Color(0xFFBE9BF6),
    'E': Color(0xFF86D98F),
    'F': Color(0xFFF38AAE),
  };
  return palette[label] ?? const Color(0xFFB0BAC6);
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
    _paintBeatGrid(canvas, size, waveTop);
    _paintBaseline(canvas, size, mid);
    _paintWaveform(
      canvas,
      size,
      waveTop: waveTop,
      waveBottom: waveBottom,
      mid: mid,
      px: px,
    );
    _paintRuler(canvas, size);
    _paintMarkers(canvas, size);
    _paintPlayhead(canvas, size, px);
  }

  void _paintSectionBands(Canvas canvas, Size size, double waveTop) {
    final h = size.height - waveTop;
    for (final s in sections) {
      final sx0 = _x(s.start, size.width);
      final sx1 = _x(s.end, size.width);
      final active = positionSec >= s.start && positionSec < s.end;
      final hue = _sectionHue(s.label);
      canvas
        ..drawRect(
          Rect.fromLTRB(sx0, waveTop, sx1, size.height),
          Paint()..color = hue.withValues(alpha: active ? 0.20 : 0.075),
        )
        // Boundary line spanning the full height (ties marker → band → wave).
        ..drawRect(
          Rect.fromLTWH(sx0, 0, 1, size.height),
          Paint()..color = const Color(0x22FFFFFF),
        );
      if (active) {
        // Frame the live band in its hue so structure reads from the band, not
        // just the marker letter.
        canvas
          ..drawRect(
            Rect.fromLTWH(sx0, waveTop, 1.5, h),
            Paint()..color = hue.withValues(alpha: 0.7),
          )
          ..drawRect(
            Rect.fromLTWH(sx1 - 1.5, waveTop, 1.5, h),
            Paint()..color = hue.withValues(alpha: 0.7),
          )
          ..drawRect(
            Rect.fromLTRB(sx0, waveTop, sx1, waveTop + 2),
            Paint()..color = hue.withValues(alpha: 0.9),
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
    final h = size.height - waveTop;
    var bar = 1;
    for (var t = barSec; t < trackDurationSec; t += barSec, bar++) {
      final x = _x(t, size.width);
      canvas.drawRect(
        Rect.fromLTWH(x, waveTop, 1, h),
        Paint()
          ..color = bar % 4 == 0
              ? const Color(0x12FFFFFF)
              : const Color(0x07FFFFFF),
      );
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
    final dx = size.width / n;
    // A single mirrored envelope: across the tops, back along the bottoms.
    final path = Path()..moveTo(0, mid);
    for (var i = 0; i < n; i++) {
      final x = i * dx + dx / 2;
      final h = (amplitudes[i] * maxH).clamp(1.0, maxH);
      path.lineTo(x, mid - h / 2);
    }
    for (var i = n - 1; i >= 0; i--) {
      final x = i * dx + dx / 2;
      final h = (amplitudes[i] * maxH).clamp(1.0, maxH);
      path.lineTo(x, mid + h / 2);
    }
    path
      ..lineTo(0, mid)
      ..close();

    final played = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        Offset(0, waveTop),
        Offset(0, waveBottom),
        const [_Chrome.wavePlayedTop, _Chrome.wavePlayedBot],
      );
    final ahead = Paint()
      ..isAntiAlias = true
      ..color = _Chrome.waveAhead;
    final capPlayed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true
      ..color = _Chrome.waveCap;
    final capAhead = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true
      ..color = const Color(0x66808E9B);

    // Ahead fill on the right of the playhead, played on the left — one
    // envelope split at the playhead, each with a crisp edge cap.
    canvas
      ..save()
      ..clipRect(Rect.fromLTWH(px, 0, size.width - px, size.height))
      ..drawPath(path, ahead)
      ..drawPath(path, capAhead)
      ..restore()
      ..save()
      ..clipRect(Rect.fromLTWH(0, 0, px, size.height))
      ..drawPath(path, played)
      ..drawPath(path, capPlayed)
      ..restore();
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
      if (sx0 < lastRight + 4) continue;
      final left = sx0 + 1;
      const top = _rulerH + 0.5;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, pillW, pillH),
        const Radius.circular(3),
      );
      canvas.drawRRect(
        rrect,
        Paint()..color = active ? hue : _Chrome.markerPill,
      );
      if (!active) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = hue.withValues(alpha: 0.5),
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
      // Soft accent glow flanking the line, below the ruler.
      ..drawRect(
        Rect.fromLTWH(px - 1.5, _rulerH, 3, size.height - _rulerH),
        Paint()..color = const Color(0x224DD6C0),
      )
      // The crisp full-height playhead line (brighter while playing).
      ..drawRect(
        Rect.fromLTWH(px - 0.75, 0, 1.5, size.height),
        Paint()..color = playing ? Colors.white : Colors.white70,
      );
    // A rounded slider-thumb knob at the top with a soft shadow, so the
    // playhead reads as draggable rather than a tick.
    final knob = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(px, 6), width: 13, height: 12),
      const Radius.circular(4),
    );
    canvas
      ..drawRRect(
        knob.shift(const Offset(0, 1)),
        Paint()
          ..color = const Color(0x66000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawRRect(
        knob,
        Paint()
          ..isAntiAlias = true
          ..color = _Chrome.accent,
      )
      // A thin grip notch in the knob centre.
      ..drawRect(
        Rect.fromLTWH(px - 0.5, 3, 1, 6),
        Paint()..color = const Color(0x66062521),
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
