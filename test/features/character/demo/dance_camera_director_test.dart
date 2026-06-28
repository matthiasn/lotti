import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/character/demo/dance_camera_director.dart';

/// Every section label the director branches on, plus a couple it treats as the
/// default "verse" pocket — so the generator exercises the whole switch.
const _sections = <String>[
  'intro',
  'verse',
  'pre-chorus',
  'chorus',
  'post-chorus',
  'bridge',
  'outro',
];

/// The reserved money hero: the ONE arrival the director lets past the ~1.6 cap.
bool _isHeroArrival(DanceCameraContext c) =>
    c.energetic &&
    c.section == 'post-chorus' &&
    c.build > 0.74 &&
    c.sectionPhase > 0.90;

/// Direct context builder with defaults so the example tests state only the
/// fields that matter to the shot under test.
DanceCameraContext _ctx({
  String section = 'chorus',
  bool energetic = true,
  double build = 0.5,
  double phrasePhase = 0,
  double sectionPhase = 0,
  int sectionBar = 0,
  int barIndex = 0,
}) => DanceCameraContext(
  section: section,
  energetic: energetic,
  build: build,
  phrasePhase: phrasePhase,
  sectionPhase: sectionPhase,
  barIndex: barIndex,
  sectionBar: sectionBar,
  beatInBar: 0,
  beatFraction: 0,
);

extension _AnyDanceCtx on glados.Any {
  /// A random director context spanning every section, both energy states, and
  /// the full build/phase/bar ranges — the input space for the invariants.
  glados.Generator<DanceCameraContext> get danceCtx =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(0, _sections.length - 1),
        glados.IntAnys(this).intInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.IntAnys(this).intInRange(0, 12),
        (sIdx, en, build, phrase, secPhase, secBar) => _ctx(
          section: _sections[sIdx],
          energetic: en == 1,
          build: build,
          phrasePhase: phrase,
          sectionPhase: secPhase,
          sectionBar: secBar,
          barIndex: secBar,
        ),
      );
}

void main() {
  group('cameraContext', () {
    test('derives bar index, phrase phase and beat-in-bar from the grid', () {
      final c = cameraContext(
        beat: 13,
        anchorBeat: 1,
        loopLengthBeats: 12,
        beatsPerBar: 4,
        section: 'chorus',
        energetic: true,
        build: 0.5,
      );
      // rel = 12 -> bar 3, exactly one phrase elapsed (phase wraps to 0).
      expect(c.barIndex, 3);
      expect(c.phrasePhase, closeTo(0, 1e-9));
      expect(c.beatInBar, 0);
      expect(c.beatFraction, closeTo(0, 1e-9));
    });

    test('clamps build/sectionPhase to 0..1 and floors a negative bar', () {
      final c = cameraContext(
        beat: 5,
        anchorBeat: 0,
        loopLengthBeats: 12,
        beatsPerBar: 4,
        section: 'verse',
        energetic: true,
        build: 1.5,
        sectionPhase: -0.3,
        sectionBar: -2,
      );
      expect(c.build, 1.0);
      expect(c.sectionPhase, 0.0);
      expect(c.sectionBar, 0);
    });
  });

  group('cameraShot — section treatments', () {
    test('calm sections establish wide with a head-clearing dy and no pan', () {
      final s = cameraShot(
        _ctx(section: 'intro', energetic: false, phrasePhase: 0.3),
      );
      expect(s.zoom, closeTo(1.06, 0.03)); // establish + a small breathe
      expect(s.dx, 0);
      expect(s.dy, kHorizonDropPx);
    });

    test('pre-chorus is a strictly monotonic crane-push, dead centre', () {
      var prev = -1.0;
      for (final p in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0]) {
        final s = cameraShot(_ctx(section: 'pre-chorus', sectionPhase: p));
        expect(s.dx, 0, reason: 'p=$p');
        expect(s.dy, 0, reason: 'p=$p');
        expect(s.zoom, greaterThan(prev), reason: 'p=$p');
        prev = s.zoom;
      }
      expect(
        cameraShot(_ctx(section: 'pre-chorus')).zoom,
        closeTo(1.22, 1e-9),
      );
      expect(
        cameraShot(_ctx(section: 'pre-chorus', sectionPhase: 1)).zoom,
        closeTo(1.52, 1e-9),
      );
    });

    test('each chorus owns a distinct home: c1 centred, c2 left, c3 right', () {
      // chorus 1 (build < 0.30): a centred home on the downbeat.
      expect(
        cameraShot(_ctx(build: 0.15)).dx,
        0,
      );
      // chorus 2 (0.30..0.62): home leans LEFT toward the silver backup.
      expect(
        cameraShot(_ctx(build: 0.45, sectionBar: 1)).dx,
        greaterThan(0),
      );
      // chorus 3 (build > 0.62): home leans RIGHT toward the dark backup.
      expect(
        cameraShot(_ctx(build: 0.70, sectionBar: 2)).dx,
        lessThan(0),
      );
    });

    test('a deep lean marries a tighter zoom to the pan (fills the pair)', () {
      // chorus 3's deep-lean bar zooms tighter than its breathing home bar.
      final home = cameraShot(
        _ctx(build: 0.70, sectionBar: 2),
      );
      final deepLean = cameraShot(
        _ctx(build: 0.70, sectionBar: 3),
      );
      expect(deepLean.zoom, greaterThan(home.zoom));
      expect(deepLean.dx.abs(), greaterThan(home.dx.abs()));
    });

    test('bridge is one swing left->right, tightest at the held extremes', () {
      final start = cameraShot(_ctx(section: 'bridge'));
      final mid = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.5));
      final end = cameraShot(_ctx(section: 'bridge', sectionPhase: 1));
      expect(
        start.dx,
        greaterThan(0),
      ); // hands from the silver (left) backup...
      expect(end.dx, lessThan(0)); // ...to the dark (right) backup
      expect(mid.dx, closeTo(0, 1e-6)); // through a centred hand-off pass
      // One continuous swing, never a per-bar pendulum: dx falls monotonically.
      var prev = double.infinity;
      for (var i = 0; i <= 20; i++) {
        final dx = cameraShot(_ctx(section: 'bridge', sectionPhase: i / 20)).dx;
        expect(dx, lessThan(prev), reason: 'sp=${i / 20}');
        prev = dx;
      }
      // Zoom married to lean depth: tighter at the extremes than the mid-pass.
      expect(start.zoom, greaterThan(mid.zoom));
      expect(end.zoom, greaterThan(mid.zoom));
    });

    test('verse is a living medium: slow push plus a two-way drift', () {
      final a = cameraShot(_ctx(section: 'verse'));
      final b = cameraShot(_ctx(section: 'verse', sectionPhase: 1));
      expect(a.zoom, closeTo(1.36, 1e-9));
      expect(b.zoom, closeTo(1.45, 1e-9));
      expect(b.zoom, greaterThan(a.zoom)); // pushes across the section
      expect(a.dy, 0);
      // The drift sways both ways within a phrase, so the verse never parks.
      expect(
        cameraShot(_ctx(section: 'verse', phrasePhase: 0.25)).dx,
        greaterThan(0),
      );
      expect(
        cameraShot(_ctx(section: 'verse', phrasePhase: 0.75)).dx,
        lessThan(0),
      );
    });

    test('outro de-escalates toward the establish and eases its dy in', () {
      final a = cameraShot(_ctx(section: 'outro'));
      final b = cameraShot(_ctx(section: 'outro', sectionPhase: 1));
      expect(a.zoom, closeTo(1.48, 1e-9));
      expect(b.zoom, closeTo(1.10, 1e-9));
      expect(b.zoom, lessThan(a.zoom));
      expect(a.dy, 0);
      expect(b.dy, closeTo(kHorizonDropPx, 1e-9));
    });
  });

  group('cameraShot — the reserved hero climax', () {
    test('closing post-chorus holds the coil flat, loads off-centre, cuts', () {
      // The coil tail pins zoom at the ~1.56 ceiling across the whole wind-up,
      // spending no zoom before the cut.
      for (final sp in [0.5, 0.62, 0.74, 0.86, 0.90]) {
        expect(
          cameraShot(
            _ctx(section: 'post-chorus', build: 0.9, sectionPhase: sp),
          ).zoom,
          closeTo(1.56, 0.005),
          reason: 'sp=$sp',
        );
      }
      // ...while a wide lateral sway visibly LOADS the frame off-centre.
      expect(
        cameraShot(
          _ctx(section: 'post-chorus', build: 0.9, sectionPhase: 0.62),
        ).dx.abs(),
        greaterThan(50),
      );
      // The cut: a single big step off the held plateau onto the hero.
      final preCut = cameraShot(
        _ctx(section: 'post-chorus', build: 0.9, sectionPhase: 0.90),
      );
      final hero = cameraShot(
        _ctx(section: 'post-chorus', build: 0.9, sectionPhase: 1),
      );
      expect(preCut.zoom, closeTo(1.56, 0.005)); // still flat at the edge
      expect(hero.zoom - preCut.zoom, greaterThan(0.5)); // arrives, not creeps
    });

    test('the hero is a hard cut: no zoom ever lands between coil and hero', () {
      // A smoothstep ramp would leave intermediate framings on screen and soften
      // the punch; the hero is a discontinuous STEP, so every post-chorus zoom is
      // either on the coil plateau (<=1.56) or exactly at the hero (2.10).
      for (var i = 0; i <= 400; i++) {
        final z = cameraShot(
          _ctx(section: 'post-chorus', build: 0.9, sectionPhase: i / 400),
        ).zoom;
        final onCoil = z <= 1.56 + 1e-9;
        final atHero = (z - 2.10).abs() < 1e-9;
        expect(onCoil || atHero, isTrue, reason: 'sp=${i / 400} z=$z');
      }
    });

    test('the hero is the single tightest framing and arrives centred', () {
      final hero = cameraShot(
        _ctx(
          section: 'post-chorus',
          build: 0.95,
          sectionPhase: 1,
          sectionBar: 8,
        ),
      );
      expect(hero.zoom, closeTo(2.10, 1e-9));
      expect(hero.dx, 0);
      expect(hero.dy, 0);

      // No other section, at any phase/bar/build, reaches anywhere near it.
      var maxOther = 0.0;
      for (final section in _sections) {
        for (var b = 0; b <= 10; b++) {
          for (var bar = 0; bar < 12; bar++) {
            for (var ph = 0; ph <= 4; ph++) {
              for (var sp = 0; sp <= 10; sp++) {
                final c = _ctx(
                  section: section,
                  build: b / 10,
                  phrasePhase: ph / 4,
                  sectionPhase: sp / 10,
                  sectionBar: bar,
                  barIndex: bar,
                );
                if (_isHeroArrival(c)) continue;
                final z = cameraShot(c).zoom;
                if (z > maxOther) maxOther = z;
              }
            }
          }
        }
      }
      expect(maxOther, lessThanOrEqualTo(1.62));
      expect(hero.zoom, greaterThan(maxOther + 0.4));
    });
  });

  group('cameraShot — invariants (glados)', () {
    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'no shot ever exceeds the reserved hero zoom, and all output is finite',
      (c) {
        final s = cameraShot(c);
        expect(s.zoom, lessThanOrEqualTo(2.1000001), reason: '$c');
        expect(s.zoom, greaterThan(1.0), reason: '$c');
        expect(s.zoom.isFinite, isTrue, reason: '$c');
        expect(s.dx.isFinite, isTrue, reason: '$c');
        expect(s.dy.isFinite, isTrue, reason: '$c');
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'every shot but the reserved hero arrival stays capped near 1.6',
      (c) {
        if (_isHeroArrival(c)) return; // its own register, bounded above by 2.2
        expect(cameraShot(c).zoom, lessThanOrEqualTo(1.62), reason: '$c');
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'never pans further than centring a side cat at the current zoom',
      (c) {
        final s = cameraShot(c);
        expect(
          s.dx.abs(),
          lessThanOrEqualTo(s.zoom * kSideCatCentreRef + 1e-6),
          reason: '$c',
        );
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'dy follows the framing contract: calm trims, dance rides flat, outro eases',
      (c) {
        final dy = cameraShot(c).dy;
        if (!c.energetic) {
          expect(dy, kHorizonDropPx, reason: '$c');
        } else if (c.section == 'outro') {
          expect(dy, inInclusiveRange(0, kHorizonDropPx), reason: '$c');
        } else {
          expect(dy, 0, reason: '$c');
        }
      },
      tags: 'glados',
    );
  });
}
