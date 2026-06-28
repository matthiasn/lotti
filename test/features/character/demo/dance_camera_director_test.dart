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

  group('isHardCut', () {
    test('stays disabled now that the tight climax crop is removed', () {
      for (final section in _sections) {
        for (final sp in [0.0, 0.5, 0.95, 1.0]) {
          expect(
            isHardCut(
              _ctx(section: section, build: 0.9, sectionPhase: sp),
            ),
            isFalse,
            reason: '$section sp=$sp',
          );
        }
      }
    });
  });

  group('isChorusDrop — the Afrobeats cut on the "1"', () {
    test('fires on the downbeat of a chorus, not mid-section', () {
      // The rig snaps to the chorus home on the opening beats, then holds.
      expect(isChorusDrop(_ctx()), isTrue); // sectionPhase 0 = the downbeat
      expect(isChorusDrop(_ctx(sectionPhase: 0.01)), isTrue);
      expect(isChorusDrop(_ctx(sectionPhase: 0.2)), isFalse);
      expect(isChorusDrop(_ctx(sectionPhase: 0.9)), isFalse);
    });

    test('only choruses fire the chorus drop — other sections do not', () {
      // The bridge cuts too, but via its own [isBridgeCut], not this predicate.
      for (final section in ['verse', 'bridge', 'pre-chorus', 'outro']) {
        expect(
          isChorusDrop(_ctx(section: section)),
          isFalse,
          reason: section,
        );
      }
      // post-chorus is reached by a dolly too.
      expect(isChorusDrop(_ctx(section: 'post-chorus', build: 0.9)), isFalse);
    });

    test('does not fire when the section is calm', () {
      expect(isChorusDrop(_ctx(energetic: false)), isFalse);
    });

    test('the chorus target is continuous across the drop (only the rig cuts)', () {
      // The cut lives in the rig, not the director: cameraShot for a chorus does
      // not jump across the downbeat — sweeping sectionPhase through the drop, the
      // target moves smoothly, so the snap is purely [isChorusDrop] telling the
      // rig to arrive by a cut.
      var prev = cameraShot(_ctx(build: 0.45));
      for (var sp = 0.0; sp <= 0.1; sp += 0.005) {
        final s = cameraShot(_ctx(build: 0.45, sectionPhase: sp));
        expect((s.zoom - prev.zoom).abs(), lessThan(0.02), reason: 'sp=$sp');
        expect((s.dx - prev.dx).abs(), lessThan(20), reason: 'sp=$sp');
        prev = s;
      }
    });
  });

  group('isBridgeCut — the bridge singer-feature cuts', () {
    test('fires at the bridge open and the mid-bridge hand-off', () {
      // The rig snaps onto the silver singer at the open, then onto the brown
      // singer at the hand-off — the two frames where the feature changes.
      expect(isBridgeCut(_ctx(section: 'bridge')), isTrue); // open (sp 0)
      expect(isBridgeCut(_ctx(section: 'bridge', sectionPhase: 0.01)), isTrue);
      expect(isBridgeCut(_ctx(section: 'bridge', sectionPhase: 0.5)), isTrue);
      expect(isBridgeCut(_ctx(section: 'bridge', sectionPhase: 0.51)), isTrue);
    });

    test('does not fire mid-feature — the rig holds between the cuts', () {
      for (final sp in [0.2, 0.45, 0.7, 0.99]) {
        expect(
          isBridgeCut(_ctx(section: 'bridge', sectionPhase: sp)),
          isFalse,
          reason: 'sp=$sp',
        );
      }
    });

    test('only the bridge cuts this way, and only while it performs', () {
      for (final section in ['verse', 'chorus', 'pre-chorus', 'outro']) {
        expect(isBridgeCut(_ctx(section: section)), isFalse, reason: section);
        expect(
          isBridgeCut(_ctx(section: section, sectionPhase: 0.5)),
          isFalse,
          reason: section,
        );
      }
      // A calm bridge performs no singer-features, so it is not cut to either.
      expect(isBridgeCut(_ctx(section: 'bridge', energetic: false)), isFalse);
    });

    test('the cut aligns with the dx sign-flip in the bridge target', () {
      // isBridgeCut must fire exactly where the bridge home swaps singer, or the
      // hand-off snaps on the wrong frame.
      final before = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.49));
      final after = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.5));
      expect(before.dx.sign, isNot(after.dx.sign));
      expect(isBridgeCut(_ctx(section: 'bridge', sectionPhase: 0.5)), isTrue);
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

    test('bridge is two committed singer-features with a cut between', () {
      // The bridge follows the VOICE: first half spotlights the silver (left)
      // backup (+dx), second half the brown (right) backup (-dx), while keeping
      // the full trio readable. Each home is CONSTANT across its half (the rig
      // holds it after the cut), and dx flips sign at the mid-bridge hand-off —
      // the cut (see [isBridgeCut]).
      final earlyA = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.1));
      final earlyB = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.4));
      final lateA = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.6));
      final lateB = cameraShot(_ctx(section: 'bridge', sectionPhase: 0.9));
      // Silver feature: leans LEFT (+dx), held flat across the first half.
      expect(earlyA.dx, greaterThan(0));
      expect(earlyA.dx, closeTo(earlyB.dx, 1e-9));
      expect(earlyA.zoom, closeTo(earlyB.zoom, 1e-9));
      // Brown feature: leans RIGHT (-dx), held flat across the second half.
      expect(lateA.dx, lessThan(0));
      expect(lateA.dx, closeTo(lateB.dx, 1e-9));
      // The hand-off is a hard CUT: dx flips by a big jump across 0.5, not a
      // continuous sweep through centre.
      expect(earlyB.dx - lateA.dx, greaterThan(380));
      // Both features hold the same favoured-trio zoom, under the ceiling.
      expect(earlyA.zoom, closeTo(1.50, 1e-9));
      expect(lateA.zoom, closeTo(1.50, 1e-9));
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

  group('cameraShot — continuous (dolly) within every dollied section', () {
    // The director's TARGET moves continuously within every DOLLIED section — the
    // genre cuts (chorus drops and the bridge singer hand-off) live in the rig,
    // not here. So sweeping sectionPhase finely (phrasePhase fixed so the
    // breathe term is constant), the target never jumps: a real per-bar cut (the
    // old homes jumped dx by ~300 / zoom by ~0.15) would blow these bounds; the
    // smooth coil sweep stays well inside them. The bridge is EXCLUDED — it is now
    // cut-driven (a dx sign-flip at the mid-bridge hand-off), covered by its own
    // singer-feature test above.
    const cases = <({String section, double build})>[
      (section: 'chorus', build: 0.15), // chorus 1
      (section: 'chorus', build: 0.45), // chorus 2 (left)
      (section: 'chorus', build: 0.70), // chorus 3 (right)
      (section: 'verse', build: 0.50),
      (section: 'pre-chorus', build: 0.20),
      (section: 'outro', build: 0.95),
      (section: 'post-chorus', build: 0.90),
    ];
    for (final cse in cases) {
      test('${cse.section} (build ${cse.build}) never jumps mid-section', () {
        var prev = cameraShot(
          _ctx(section: cse.section, build: cse.build),
        );
        for (var sp = 0.005; sp <= 1.0 + 1e-9; sp += 0.005) {
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

  group('cameraShot — final post-chorus hook', () {
    test('holds a grounded band, loads off-centre, and resolves continuously', () {
      // The final hook stays in a ~1.56 band with ONE motivated mid-coil push
      // and no late 2.30 close-crop jump.
      for (final sp in [0.5, 0.62, 0.74, 0.86, 0.90, 0.96, 1.0]) {
        final s = cameraShot(
          _ctx(section: 'post-chorus', build: 0.9, sectionPhase: sp),
        );
        expect(
          s.zoom,
          inInclusiveRange(1.54, 1.62),
          reason: 'sp=$sp',
        );
        expect(s.dy, 0, reason: 'sp=$sp');
      }
      // The lateral sway is beat-phrased (phrasePhase): at a quarter phrase it
      // loads the frame well off-centre.
      expect(
        cameraShot(
          _ctx(
            section: 'post-chorus',
            build: 0.9,
            sectionPhase: 0.3,
            phrasePhase: 0.25,
          ),
        ).dx.abs(),
        greaterThan(50),
      );
      expect(
        cameraShot(
          _ctx(
            section: 'post-chorus',
            build: 0.9,
            sectionPhase: 0.45,
            phrasePhase: 0.25,
          ),
        ).dx.abs(),
        lessThan(150),
      );
      // The finish resolves from the same grounded band instead of jumping into
      // a separate crop register.
      final preFinish = cameraShot(
        _ctx(section: 'post-chorus', build: 0.9, sectionPhase: 0.90),
      );
      final finish = cameraShot(
        _ctx(section: 'post-chorus', build: 0.9, sectionPhase: 1),
      );
      expect(preFinish.zoom, closeTo(1.56, 0.01));
      expect((finish.zoom - preFinish.zoom).abs(), lessThan(0.03));
      expect(finish.dy, 0);
    });

    test('the whole final hook stays continuous and capped', () {
      var prev = cameraShot(_ctx(section: 'post-chorus', build: 0.9));
      for (var i = 0; i <= 400; i++) {
        final s = cameraShot(
          _ctx(section: 'post-chorus', build: 0.9, sectionPhase: i / 400),
        );
        expect(s.zoom, lessThanOrEqualTo(1.62), reason: 'sp=${i / 400}');
        expect(
          (s.zoom - prev.zoom).abs(),
          lessThan(0.01),
          reason: 'sp=${i / 400}',
        );
        prev = s;
      }
    });

    test('no section exceeds the grounded dance ceiling', () {
      var maxShot = 0.0;
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
              final z = cameraShot(c).zoom;
              if (z > maxShot) maxShot = z;
            }
          }
        }
      }
      expect(maxShot, lessThanOrEqualTo(1.62));
    });
  });

  group('cameraShot — invariants (glados)', () {
    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'no shot ever exceeds the grounded dance ceiling, and all output is finite',
      (c) {
        final s = cameraShot(c);
        expect(s.zoom, lessThanOrEqualTo(1.6200001), reason: '$c');
        expect(s.zoom, greaterThan(1.0), reason: '$c');
        expect(s.zoom.isFinite, isTrue, reason: '$c');
        expect(s.dx.isFinite, isTrue, reason: '$c');
        expect(s.dy.isFinite, isTrue, reason: '$c');
      },
      tags: 'glados',
    );

    glados.Glados(glados.any.danceCtx, glados.ExploreConfig(numRuns: 300)).test(
      'hard cuts stay disabled while the close-crop hero is removed',
      (c) {
        expect(isHardCut(c), isFalse, reason: '$c');
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
      'dy contract: calm trims, dance flat, outro eases',
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
