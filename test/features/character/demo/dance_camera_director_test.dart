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

/// Direct context builder with defaults so the example tests state only the
/// fields that matter to the shot under test.
DanceCameraContext _ctx({
  String section = 'chorus',
  bool energetic = true,
  double build = 0.5,
  double phrasePhase = 0,
  double sectionPhase = 0,
}) => DanceCameraContext(
  section: section,
  energetic: energetic,
  build: build,
  phrasePhase: phrasePhase,
  sectionPhase: sectionPhase,
);

extension _AnyDanceCtx on glados.Any {
  /// A random director context spanning every section, both energy states, and
  /// the full build/phase ranges — the input space for the invariants.
  glados.Generator<DanceCameraContext> get danceCtx =>
      glados.CombinableAny(this).combine5(
        glados.IntAnys(this).intInRange(0, _sections.length - 1),
        glados.IntAnys(this).intInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        (sIdx, en, build, phrase, secPhase) => _ctx(
          section: _sections[sIdx],
          energetic: en == 1,
          build: build,
          phrasePhase: phrase,
          sectionPhase: secPhase,
        ),
      );
}

void main() {
  group('cameraContext', () {
    test('derives the per-phrase phase from the beat grid and wraps it', () {
      final whole = cameraContext(
        beat: 13,
        anchorBeat: 1,
        loopLengthBeats: 12,
        section: 'chorus',
        energetic: true,
        build: 0.5,
      );
      // rel = 12 = exactly one phrase → phase wraps to 0.
      expect(whole.phrasePhase, closeTo(0, 1e-9));
      final half = cameraContext(
        beat: 7,
        anchorBeat: 1,
        loopLengthBeats: 12,
        section: 'chorus',
        energetic: true,
        build: 0.5,
      );
      // rel = 6 = half a phrase.
      expect(half.phrasePhase, closeTo(0.5, 1e-9));
    });

    test('clamps build and sectionPhase into 0..1', () {
      final c = cameraContext(
        beat: 5,
        anchorBeat: 0,
        loopLengthBeats: 12,
        section: 'verse',
        energetic: true,
        build: 1.5,
        sectionPhase: -0.3,
      );
      expect(c.build, 1.0);
      expect(c.sectionPhase, 0.0);
    });
  });

  group('isHardCut — the one cut in an all-dolly piece', () {
    test('fires only on the reserved hero arrival', () {
      expect(
        isHardCut(_ctx(section: 'post-chorus', build: 0.9, sectionPhase: 0.95)),
        isTrue,
      );
    });

    test('does not fire on the coil, earlier sections, or when calm', () {
      // Still on the coil (≤ 0.93) — the rig is still dollying here.
      expect(
        isHardCut(_ctx(section: 'post-chorus', build: 0.9, sectionPhase: 0.90)),
        isFalse,
      );
      // An early post-chorus (build 0.5 < 0.74, so not the closing hook).
      expect(
        isHardCut(_ctx(section: 'post-chorus', sectionPhase: 0.99)),
        isFalse,
      );
      // A chorus, however late, is never the hero.
      expect(
        isHardCut(_ctx(build: 0.9, sectionPhase: 0.99)),
        isFalse,
      );
      // Calm sections are never cut to.
      expect(
        isHardCut(
          _ctx(
            section: 'post-chorus',
            energetic: false,
            build: 0.9,
            sectionPhase: 0.99,
          ),
        ),
        isFalse,
      );
    });

    test('agrees frame-for-frame with the 2.10 hero shot', () {
      // The predicate drives the rig's snap; it must fire on exactly the frames
      // where the shot is the 2.10 hero, or the cut lands on the wrong frame.
      for (final sp in [0.90, 0.92, 0.94, 0.96, 1.0]) {
        final c = _ctx(section: 'post-chorus', build: 0.9, sectionPhase: sp);
        final shotIsHero = (cameraShot(c).zoom - 2.10).abs() < 1e-9;
        expect(isHardCut(c), shotIsHero, reason: 'sp=$sp');
      }
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
      expect(cameraShot(_ctx(section: 'pre-chorus')).zoom, closeTo(1.22, 1e-9));
      expect(
        cameraShot(_ctx(section: 'pre-chorus', sectionPhase: 1)).zoom,
        closeTo(1.52, 1e-9),
      );
    });

    test('each chorus owns a distinct home: c1 centred, c2 left, c3 right', () {
      // chorus 1 (build < 0.30): centred.
      expect(cameraShot(_ctx(build: 0.15)).dx, 0);
      // chorus 2 (0.30..0.62): leans LEFT toward the silver backup (+dx).
      expect(cameraShot(_ctx(build: 0.45)).dx, greaterThan(0));
      // chorus 3 (build > 0.62): leans RIGHT toward the dark backup (-dx).
      expect(cameraShot(_ctx(build: 0.70)).dx, lessThan(0));
    });

    test('a chorus home holds its lean and pushes gently across the section', () {
      // The home is STABLE (not a per-bar cut cycle): the lean keeps its sign for
      // the whole section while a slow push tightens it — the rig dollies INTO
      // the home, then it just breathes.
      final start = cameraShot(_ctx(build: 0.45));
      final end = cameraShot(_ctx(build: 0.45, sectionPhase: 1));
      expect(start.dx, greaterThan(0));
      expect(end.dx, greaterThan(0)); // same committed side throughout
      expect(end.zoom, greaterThan(start.zoom)); // slow push, never a snap
      expect(end.zoom - start.zoom, lessThan(0.1)); // gentle, not a jump
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

  group('cameraShot — continuous (dolly) within every section', () {
    // The whole point of the dolly-first rewrite: outside the one hero cut, the
    // director's target moves CONTINUOUSLY as the section progresses — no per-bar
    // snaps. Sweep sectionPhase finely (phrasePhase fixed so the breathe term is
    // constant) and assert adjacent frames never jump. A real cut (the old per-bar
    // homes jumped dx by ~300 / zoom by ~0.15) would blow these bounds; the
    // smooth-but-fast coil/bridge sweeps stay well inside them.
    const cases = <({String section, double build})>[
      (section: 'chorus', build: 0.15), // chorus 1
      (section: 'chorus', build: 0.45), // chorus 2 (left)
      (section: 'chorus', build: 0.70), // chorus 3 (right)
      (section: 'verse', build: 0.50),
      (section: 'bridge', build: 0.50),
      (section: 'pre-chorus', build: 0.20),
      (section: 'outro', build: 0.95),
      (section: 'post-chorus', build: 0.90), // the coil, BEFORE the hero cut
    ];
    for (final cse in cases) {
      test('${cse.section} (build ${cse.build}) never jumps mid-section', () {
        // Stop at 0.90 so the post-chorus sweep stays on the coil, not the hero.
        var prev = cameraShot(
          _ctx(section: cse.section, build: cse.build),
        );
        for (var sp = 0.005; sp <= 0.90 + 1e-9; sp += 0.005) {
          final s = cameraShot(
            _ctx(section: cse.section, build: cse.build, sectionPhase: sp),
          );
          expect(
            (s.zoom - prev.zoom).abs(),
            lessThan(0.03),
            reason: '${cse.section} zoom jumped at sp=$sp',
          );
          expect(
            (s.dx - prev.dx).abs(),
            lessThan(40),
            reason: '${cse.section} pan jumped at sp=$sp',
          );
          prev = s;
        }
      });
    }
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
      // The hero is a discontinuous STEP, so every post-chorus zoom is either on
      // the coil plateau (<=1.56) or exactly at the hero (2.10) — the one place
      // the rig is told to snap rather than dolly.
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
        _ctx(section: 'post-chorus', build: 0.95, sectionPhase: 1),
      );
      expect(hero.zoom, closeTo(2.10, 1e-9));
      expect(hero.dx, 0);
      expect(hero.dy, 0);

      // No other section, at any phase/build, reaches anywhere near it.
      var maxOther = 0.0;
      for (final section in _sections) {
        for (var b = 0; b <= 10; b++) {
          for (var ph = 0; ph <= 4; ph++) {
            for (var sp = 0; sp <= 10; sp++) {
              final c = _ctx(
                section: section,
                build: b / 10,
                phrasePhase: ph / 4,
                sectionPhase: sp / 10,
              );
              if (isHardCut(c)) continue;
              final z = cameraShot(c).zoom;
              if (z > maxOther) maxOther = z;
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
        if (isHardCut(c)) return; // its own register, bounded above by 2.10
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
      'dy follows the framing contract: calm trims, dance flat, outro eases',
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
