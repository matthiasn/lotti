import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/dance_phrase.dart';

void main() {
  group('DancePhrase', () {
    const phrase = DancePhrase(
      frameCount: 32,
      supports: [
        DanceSupportSpan(
          footBoneId: 'foot.L',
          freeFootBoneId: 'foot.R',
          startFrame: 0,
          endFrame: 16,
          loadFrame: 4,
          releaseFrame: 8,
          maxPelvisDistance: 36,
          pocketScaleY: 0.92,
          label: 'left pocket',
        ),
        DanceSupportSpan(
          footBoneId: 'foot.R',
          freeFootBoneId: 'foot.L',
          startFrame: 16,
          endFrame: 32,
          loadFrame: 20,
          releaseFrame: 24,
          maxPelvisDistance: 36,
          pocketScaleY: 0.92,
          label: 'right pocket',
        ),
      ],
      sections: [
        DancePhraseSection(
          name: 'pocket',
          startFrame: 0,
          endFrame: 16,
          intent: 'settle over the left support',
        ),
        DancePhraseSection(
          name: 'answer',
          startFrame: 16,
          endFrame: 32,
          intent: 'answer on the right support',
        ),
      ],
      moves: [
        DanceMoveCue(
          name: 'left pocket hit',
          startFrame: 0,
          endFrame: 8,
          accentFrame: 4,
          featuredDancer: 'lead',
          signature: 'low shoulder pocket over left support',
        ),
        DanceMoveCue(
          name: 'right answer hit',
          startFrame: 16,
          endFrame: 32,
          accentFrame: 20,
          featuredDancer: 'right',
          signature: 'right dancer answers with inside-arm lift',
        ),
      ],
    );

    test('maps authored frames to normalized clip phase', () {
      expect(phrase.phaseOf(0), 0);
      expect(phrase.phaseOf(4), 0.125);
      expect(phrase.phaseOf(16), 0.5);
      expect(phrase.phaseOf(32), 1);
    });

    test('compiles labelled support windows into ground spans', () {
      final spans = phrase.contactSpans();

      expect(spans.map((span) => span.bone), ['foot.L', 'foot.R']);
      expect(spans.map((span) => span.start), [0, 0.5]);
      expect(spans.map((span) => span.end), [0.5, 1]);
      expect(phrase.supports.map((support) => support.label), [
        'left pocket',
        'right pocket',
      ]);
    });

    test('looks up support and weight intent by frame and phase', () {
      expect(phrase.supportAtFrame(0).footBoneId, 'foot.L');
      expect(phrase.supportAtFrame(15).footBoneId, 'foot.L');
      expect(phrase.supportAtFrame(16).footBoneId, 'foot.R');
      expect(phrase.supportAtFrame(32).footBoneId, 'foot.L');
      expect(phrase.supportAtPhase(0.62).footBoneId, 'foot.R');

      final rightPocket = phrase.supportAtFrame(20);
      expect(rightPocket.freeFootBoneId, 'foot.L');
      expect(rightPocket.loadFrame, 20);
      expect(rightPocket.releaseFrame, 24);
      expect(rightPocket.maxPelvisDistance, 36);
      expect(rightPocket.pocketScaleY, 0.92);
      expect(rightPocket.containsFrame(31), isTrue);
      expect(rightPocket.containsFrame(32), isFalse);
    });

    test('looks up named choreographic sections by frame and phase', () {
      expect(phrase.sectionAtFrame(0).name, 'pocket');
      expect(phrase.sectionAtFrame(15).name, 'pocket');
      expect(phrase.sectionAtFrame(16).name, 'answer');
      expect(phrase.sectionAtFrame(32).name, 'pocket');
      expect(phrase.sectionAtPhase(0.75).intent, 'answer on the right support');
    });

    test('looks up concrete move cues by frame and phase', () {
      expect(phrase.moveAtFrame(0).name, 'left pocket hit');
      expect(phrase.moveAtFrame(7).accentFrame, 4);
      expect(phrase.moveAtFrame(16).name, 'right answer hit');
      expect(phrase.moveAtFrame(32).featuredDancer, 'lead');
      expect(phrase.moveAtPhase(0.64).signature, contains('inside-arm lift'));
    });

    test('compiles named move signatures over base choreography keys', () {
      const signatures = [
        DanceMoveSignature(
          moveName: 'left pocket hit',
          bodyAccents: [
            DanceBodyAccent(
              4,
              radiusFrames: 2,
              rootDy: 1.5,
              chestRotation: -0.04,
            ),
          ],
          ikTargetArcs: {
            'hand.R': [
              DanceIkTargetArc(
                name: 'right hand move-level lift',
                startFrame: 4,
                peakFrame: 6,
                endFrame: 8,
                startX: 18,
                startY: 30,
                peakX: 48,
                peakY: -12,
                endX: 28,
                endY: 24,
                controlPoints: [
                  DanceIkTargetArcPoint(5, x: 36, y: 10),
                ],
              ),
            ],
          },
          jointKeys: {
            'foot.R': [
              DanceJointKey(4, rotation: 0.32),
            ],
          },
          ikTargetKeys: {
            'hand.L': [
              DanceIkTargetKey(4, x: -42, y: 6),
            ],
            'hand.R': [
              DanceIkTargetKey(6, x: 42, y: -8),
            ],
          },
        ),
      ];

      final bodyAccents = phrase.moveBodyAccents(signatures);
      final footKeys = phrase.mergeJointKeys(
        baseKeys: const [
          DanceJointKey(0, rotation: -0.1),
          DanceJointKey(4),
          DanceJointKey(32, rotation: -0.1),
        ],
        signatures: signatures,
        boneId: 'foot.R',
      );
      final handKeys = phrase.mergeIkTargetKeys(
        baseKeys: const [
          DanceIkTargetKey(0, x: -12, y: 24),
          DanceIkTargetKey(4, x: -18, y: 30),
          DanceIkTargetKey(32, x: -12, y: 24),
        ],
        signatures: signatures,
        targetBoneId: 'hand.L',
      );
      final rightHandKeys = phrase.mergeIkTargetKeys(
        baseKeys: const [
          DanceIkTargetKey(0, x: 12, y: 24),
          DanceIkTargetKey(4, x: 16, y: 28),
          DanceIkTargetKey(8, x: 20, y: 28),
          DanceIkTargetKey(32, x: 12, y: 24),
        ],
        signatures: signatures,
        targetBoneId: 'hand.R',
      );

      expect(bodyAccents.single.frame, 4);
      expect(bodyAccents.single.rootDy, 1.5);
      expect(bodyAccents.single.chestRotation, -0.04);
      expect(footKeys.map((key) => key.frame), [0, 4, 32]);
      expect(footKeys[1].rotation, 0.32);
      expect(handKeys.map((key) => key.frame), [0, 4, 32]);
      expect(handKeys[1].x, -42);
      expect(handKeys[1].y, 6);
      expect(rightHandKeys.map((key) => key.frame), [0, 4, 5, 6, 8, 32]);
      expect(rightHandKeys[1].x, 18);
      expect(rightHandKeys[2].x, 36);
      expect(rightHandKeys[3].x, 42);
      expect(rightHandKeys[3].y, -8);
      expect(rightHandKeys[4].x, 28);
    });

    test('builds joint channels from frame-addressed keys', () {
      final channel = phrase.jointChannel(
        const [
          DanceJointKey(0, rotation: -0.2),
          DanceJointKey(8, rotation: 0.4, scaleX: 1.1, scaleY: 0.9),
          DanceJointKey(32, rotation: -0.2),
        ],
      );

      expect(channel.sample(0).rotation, closeTo(-0.2, 1e-9));
      expect(channel.sample(0.25).rotation, closeTo(0.4, 1e-9));
      expect(channel.sample(0.25).scaleX, closeTo(1.1, 1e-9));
      expect(channel.sample(1).rotation, closeTo(-0.2, 1e-9));
    });

    test('builds neutralized joint accent pulses', () {
      final keys = phrase.jointAccentKeys(
        const [
          DanceJointAccent(8, radiusFrames: 2, rotation: 0.12),
          DanceJointAccent(
            20,
            radiusFrames: 4,
            rotation: -0.08,
            scaleX: 1.03,
            scaleY: 0.97,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10, 16, 20, 24]);
      expect(keys[0].rotation, 0);
      expect(keys[0].scaleX, 1);
      expect(keys[0].scaleY, 1);
      expect(keys[1].rotation, 0.12);
      expect(keys[1].scaleX, 1);
      expect(keys[1].scaleY, 1);
      expect(keys[4].rotation, -0.08);
      expect(keys[4].scaleX, 1.03);
      expect(keys[4].scaleY, 0.97);
    });

    test('builds root channels from frame-addressed keys', () {
      final channel = phrase.rootChannel(
        const [
          DanceRootKey(0, dx: -8, dy: 18),
          DanceRootKey(16, dx: 8, dy: 12, rotation: 0.02),
          DanceRootKey(32, dx: -8, dy: 18),
        ],
      );

      expect(channel.sample(0).dx, closeTo(-8, 1e-9));
      expect(channel.sample(0.5).dx, closeTo(8, 1e-9));
      expect(channel.sample(0.5).dy, closeTo(12, 1e-9));
      expect(channel.sample(0.5).rotation, closeTo(0.02, 1e-9));
      expect(channel.sample(1).dx, closeTo(-8, 1e-9));
    });

    test('builds synchronized body groove channels from mixed keys', () {
      const keys = [
        DanceBodyKey(
          0,
          rootDx: -8,
          rootDy: 18,
          pelvisRotation: -0.2,
          chestRotation: 0.12,
          chestScaleX: 1.02,
          chestScaleY: 0.94,
        ),
        DanceBodyKey(
          8,
          pelvisRotation: 0.4,
          chestRotation: -0.18,
          chestScaleX: 1.06,
          chestScaleY: 0.91,
        ),
        DanceBodyKey(16, rootDx: 8, rootDy: 12, rootRotation: 0.02),
        DanceBodyKey(
          32,
          rootDx: -8,
          rootDy: 18,
          pelvisRotation: -0.2,
          chestRotation: 0.12,
          chestScaleX: 1.02,
          chestScaleY: 0.94,
        ),
      ];

      final root = phrase.bodyRootChannel(keys);
      final pelvis = phrase.bodyPelvisChannel(keys);
      final chest = phrase.bodyChestChannel(keys);

      expect(root.sample(0).dx, closeTo(-8, 1e-9));
      expect(root.sample(0.5).dx, closeTo(8, 1e-9));
      expect(root.sample(0.5).dy, closeTo(12, 1e-9));
      expect(root.sample(0.5).rotation, closeTo(0.02, 1e-9));
      expect(pelvis.sample(0.25).rotation, closeTo(0.4, 1e-9));
      expect(chest.sample(0.25).rotation, closeTo(-0.18, 1e-9));
      expect(chest.sample(0.25).scaleX, closeTo(1.06, 1e-9));
      expect(chest.sample(0.25).scaleY, closeTo(0.91, 1e-9));
    });

    test('builds neutralized body accent pulses', () {
      final keys = phrase.bodyAccentKeys(
        const [
          DanceBodyAccent(
            8,
            radiusFrames: 2,
            rootDy: 3,
            pelvisRotation: 0.08,
            chestRotation: -0.04,
            chestScaleX: 1.02,
            chestScaleY: 0.96,
          ),
          DanceBodyAccent(
            20,
            radiusFrames: 4,
            rootDx: -2,
            chestScaleY: 1.02,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10, 16, 20, 24]);
      expect(keys[0].rootDy, 0);
      expect(keys[0].pelvisRotation, 0);
      expect(keys[0].chestScaleY, 1);
      expect(keys[1].rootDy, 3);
      expect(keys[1].pelvisRotation, 0.08);
      expect(keys[1].chestRotation, -0.04);
      expect(keys[1].chestScaleX, 1.02);
      expect(keys[1].chestScaleY, 0.96);
      expect(keys[4].rootDx, -2);
      expect(keys[4].rootDy, 0);
      expect(keys[4].chestRotation, 0);
      expect(keys[4].chestScaleX, 1);
      expect(keys[4].chestScaleY, 1.02);
    });

    test('combines overlapping body accent keys on the same frame', () {
      final keys = phrase.bodyAccentKeys(
        const [
          DanceBodyAccent(
            8,
            radiusFrames: 2,
            rootDy: 2,
            pelvisRotation: 0.04,
            chestScaleX: 1.02,
            chestScaleY: 0.98,
          ),
          DanceBodyAccent(
            8,
            radiusFrames: 2,
            rootDy: -1,
            pelvisRotation: 0.03,
            chestRotation: -0.02,
            chestScaleX: 1.01,
            chestScaleY: 0.99,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10]);
      final sharedFrame = keys.singleWhere((key) => key.frame == 8);
      expect(sharedFrame.rootDy, 1);
      expect(sharedFrame.pelvisRotation, closeTo(0.07, 1e-9));
      expect(sharedFrame.chestRotation, -0.02);
      expect(sharedFrame.chestScaleX, closeTo(1.0302, 1e-9));
      expect(sharedFrame.chestScaleY, closeTo(0.9702, 1e-9));
    });

    test('builds IK target channels from frame-addressed keys', () {
      final channel = phrase.ikTargetChannel(
        const [
          DanceIkTargetKey(0, x: -12, y: 24, weight: 0.4),
          DanceIkTargetKey(8, x: 18, y: 12),
          DanceIkTargetKey(32, x: -12, y: 24, weight: 0.4),
        ],
      );

      expect(channel.sample(0).x, closeTo(-12, 1e-9));
      expect(channel.sample(0).y, closeTo(24, 1e-9));
      expect(channel.sample(0).weight, closeTo(0.4, 1e-9));
      expect(channel.sample(0.25).x, closeTo(18, 1e-9));
      expect(channel.sample(0.25).y, closeTo(12, 1e-9));
      expect(channel.sample(0.25).weight, closeTo(1, 1e-9));
      expect(channel.sample(1).x, closeTo(-12, 1e-9));
    });

    test('builds named IK target arcs from start peak and settle points', () {
      final keys = phrase.ikTargetArcKeys(
        const [
          DanceIkTargetArc(
            name: 'right hand lift',
            startFrame: 12,
            peakFrame: 16,
            endFrame: 20,
            startX: 32,
            startY: 24,
            peakX: 80,
            peakY: 8,
            endX: 52,
            endY: 28,
            weight: 0.8,
            controlPoints: [
              DanceIkTargetArcPoint(14, x: 58, y: 16),
              DanceIkTargetArcPoint(18, x: 68, y: 14, weight: 0.6),
            ],
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [12, 14, 16, 18, 20]);
      expect(keys[0].x, 32);
      expect(keys[0].y, 24);
      expect(keys[0].weight, 0.8);
      expect(keys[1].x, 58);
      expect(keys[1].y, 16);
      expect(keys[1].weight, 0.8);
      expect(keys[2].x, 80);
      expect(keys[2].y, 8);
      expect(keys[3].x, 68);
      expect(keys[3].y, 14);
      expect(keys[3].weight, 0.6);
      expect(keys[4].x, 52);
      expect(keys[4].y, 28);
    });

    test('builds neutralized IK target accent pulses', () {
      final keys = phrase.ikTargetAccentKeys(
        const [
          DanceIkTargetAccent(8, radiusFrames: 2, x: -6, y: -4),
          DanceIkTargetAccent(
            20,
            radiusFrames: 4,
            x: 5,
            y: -3,
            weight: 0.7,
          ),
        ],
      );

      expect(keys.map((key) => key.frame), [6, 8, 10, 16, 20, 24]);
      expect(keys[0].x, 0);
      expect(keys[0].y, 0);
      expect(keys[0].weight, 0);
      expect(keys[1].x, -6);
      expect(keys[1].y, -4);
      expect(keys[1].weight, 1);
      expect(keys[4].x, 5);
      expect(keys[4].y, -3);
      expect(keys[4].weight, 0.7);
    });

    test('collects role style overlays by body, target, and joint', () {
      const style = DanceRoleStyle(
        bodyAccents: [
          DanceBodyAccent(8, radiusFrames: 2, rootDy: 2),
        ],
        ikTargetAccents: {
          'hand.L': [
            DanceIkTargetAccent(12, radiusFrames: 2, x: -4, y: -3),
          ],
        },
        jointAccents: {
          'torso': [
            DanceJointAccent(20, radiusFrames: 4, rotation: 0.05),
          ],
        },
      );

      final bodyKeys = style.bodyKeys(phrase);
      final handKeys = style.ikTargetKeys(phrase, 'hand.L');
      final missingHandKeys = style.ikTargetKeys(phrase, 'hand.R');
      final torsoKeys = style.jointKeys(phrase, 'torso');
      final missingJointKeys = style.jointKeys(phrase, 'head');

      expect(bodyKeys.map((key) => key.frame), [6, 8, 10]);
      expect(bodyKeys[1].rootDy, 2);
      expect(handKeys.map((key) => key.frame), [10, 12, 14]);
      expect(handKeys[1].x, -4);
      expect(handKeys[1].y, -3);
      expect(missingHandKeys, isEmpty);
      expect(torsoKeys.map((key) => key.frame), [16, 20, 24]);
      expect(torsoKeys[1].rotation, 0.05);
      expect(missingJointKeys, isEmpty);
    });

    test('rejects keys outside the authored phrase', () {
      expect(() => phrase.phaseOf(-1), throwsRangeError);
      expect(() => phrase.jointKey(33), throwsRangeError);
      expect(
        () => phrase.jointAccentKeys(
          const [DanceJointAccent(1, radiusFrames: 2, rotation: 0.1)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.bodyRootChannel(
          const [DanceBodyKey(33, rootDx: 0)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.bodyAccentKeys(
          const [DanceBodyAccent(1, radiusFrames: 2, rootDy: 1)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetAccentKeys(
          const [DanceIkTargetAccent(31, radiusFrames: 2, x: 1, y: 1)],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetArcKeys(
          const [
            DanceIkTargetArc(
              name: 'bad',
              startFrame: 28,
              peakFrame: 31,
              endFrame: 34,
              startX: 0,
              startY: 0,
              peakX: 1,
              peakY: 1,
              endX: 2,
              endY: 2,
            ),
          ],
        ),
        throwsRangeError,
      );
      expect(
        () => phrase.ikTargetKey(33, x: 0, y: 0),
        throwsRangeError,
      );
      expect(
        () => phrase.mergeIkTargetKeys(
          baseKeys: const [],
          signatures: const [
            DanceMoveSignature(
              moveName: 'missing cue',
              ikTargetKeys: {
                'hand.L': [
                  DanceIkTargetKey(4, x: 1, y: 1),
                ],
              },
            ),
          ],
          targetBoneId: 'hand.L',
        ),
        throwsStateError,
      );
      expect(
        () => phrase.mergeJointKeys(
          baseKeys: const [],
          signatures: const [
            DanceMoveSignature(
              moveName: 'left pocket hit',
              jointKeys: {
                'foot.R': [
                  DanceJointKey(33, rotation: 0.1),
                ],
              },
            ),
          ],
          boneId: 'foot.R',
        ),
        throwsRangeError,
      );
      expect(
        () => const DanceSupportSpan(
          footBoneId: 'foot.L',
          freeFootBoneId: 'foot.R',
          startFrame: 20,
          endFrame: 40,
          loadFrame: 24,
          releaseFrame: 32,
          maxPelvisDistance: 36,
          pocketScaleY: 0.92,
          label: 'bad',
        ).toGroundSpan(phrase),
        throwsRangeError,
      );
    });
  });
}
