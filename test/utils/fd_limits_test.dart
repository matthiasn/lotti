import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/fd_limits.dart';

void main() {
  group('ensureFileDescriptorSoftLimit', () {
    test('on macOS or Linux, returns a usable adjustment with no error', () {
      if (!Platform.isMacOS && !Platform.isLinux) {
        // Skip on platforms that intentionally no-op.
        return;
      }
      final adjustment = ensureFileDescriptorSoftLimit();
      expect(adjustment.error, isNull);
      // A positive-value check rejects the RLIM_INFINITY sign-flip regression
      // (-1 signed readback of UINT64_MAX from a Uint64 field).
      expect(adjustment.softAfter, greaterThan(0));
      expect(adjustment.hardAfter, greaterThan(0));
      expect(adjustment.softBefore, greaterThan(0));
      expect(adjustment.hardBefore, greaterThan(0));
      expect(adjustment.softAfter, lessThanOrEqualTo(adjustment.hardAfter));
      expect(adjustment.softAfter, greaterThanOrEqualTo(adjustment.softBefore));
      // When no error occurred, softAfter must reach the target (or the hard
      // cap if that is lower — always a positive number in practice).
      expect(
        adjustment.softAfter,
        greaterThanOrEqualTo(
          adjustment.target < adjustment.hardAfter
              ? adjustment.target
              : adjustment.hardAfter,
        ),
      );
    });

    test('target is honoured when below hard limit', () {
      if (!Platform.isMacOS && !Platform.isLinux) return;
      final adjustment = ensureFileDescriptorSoftLimit();
      // Default target is 10240. softAfter should reach it unless the hard
      // limit is lower (exceptional; would be logged as raised=false too).
      if (adjustment.hardAfter >= adjustment.target) {
        expect(adjustment.softAfter, greaterThanOrEqualTo(adjustment.target));
      }
    });

    test(
      'second call is idempotent (raised=false when already at or above)',
      () {
        if (!Platform.isMacOS && !Platform.isLinux) return;
        // Prime the limit with an explicit low target so the next call with the
        // same target never needs to raise.
        final first = ensureFileDescriptorSoftLimit(target: 4096);
        expect(first.error, isNull);
        final second = ensureFileDescriptorSoftLimit(target: 4096);
        expect(second.error, isNull);
        expect(second.raised, isFalse);
        expect(second.softAfter, greaterThanOrEqualTo(4096));
      },
    );

    test('setting a target higher than any reasonable hard caps at hard', () {
      if (!Platform.isMacOS && !Platform.isLinux) return;
      // 1 << 62 is far above kern.maxfilesperproc on any realistic system.
      // The call should either clamp or return a setrlimit error — never
      // silently exceed the hard limit.
      const absurd = 1 << 62;
      final adjustment = ensureFileDescriptorSoftLimit(target: absurd);
      expect(adjustment.softAfter, lessThanOrEqualTo(adjustment.hardAfter));
    });

    test('toString is informative', () {
      if (!Platform.isMacOS && !Platform.isLinux) return;
      final adjustment = ensureFileDescriptorSoftLimit();
      expect(adjustment.toString(), contains('FdLimitAdjustment'));
      expect(adjustment.toString(), contains('target='));
    });

    test('toString surfaces the error when one was captured', () {
      const adjustment = FdLimitAdjustment(
        softBefore: -1,
        hardBefore: -1,
        softAfter: -1,
        hardAfter: -1,
        target: 10240,
        raised: false,
        error: 'synthetic failure',
      );
      final text = adjustment.toString();
      expect(text, contains('FdLimitAdjustment'));
      expect(text, contains('target=10240'));
      expect(text, contains('synthetic failure'));
      // Error form must not include the before/after detail.
      expect(text, isNot(contains('soft ')));
    });

    group('resolveFdSoftLimitPlan', () {
      test('soft already at or above target is treated as satisfied', () {
        final plan = resolveFdSoftLimitPlan(
          softBefore: 10240,
          hardBefore: 65536,
          target: 10240,
        );
        expect(plan.alreadySatisfied, isTrue);
        expect(plan.newSoft, 10240);
      });

      test('soft comfortably above target is still satisfied', () {
        final plan = resolveFdSoftLimitPlan(
          softBefore: 20000,
          hardBefore: 65536,
          target: 10240,
        );
        expect(plan.alreadySatisfied, isTrue);
        expect(plan.newSoft, 20000);
      });

      test(
        'soft reading as RLIM_INFINITY (negative) is treated as satisfied, '
        'never *lowered* to target',
        () {
          // Linux RLIM_INFINITY reads as -1 through a Uint64 struct field.
          final plan = resolveFdSoftLimitPlan(
            softBefore: -1,
            hardBefore: -1,
            target: 10240,
          );
          expect(plan.alreadySatisfied, isTrue);
          expect(plan.newSoft, -1);
        },
      );

      test('soft below target is raised to target when hard has room', () {
        final plan = resolveFdSoftLimitPlan(
          softBefore: 256,
          hardBefore: 65536,
          target: 10240,
        );
        expect(plan.alreadySatisfied, isFalse);
        expect(plan.newSoft, 10240);
      });

      test(
        'hard reading as RLIM_INFINITY (negative on Linux) is treated '
        'as no cap, so target wins',
        () {
          final plan = resolveFdSoftLimitPlan(
            softBefore: 256,
            hardBefore: -1,
            target: 10240,
          );
          expect(plan.alreadySatisfied, isFalse);
          expect(plan.newSoft, 10240);
        },
      );

      test('target above hard is clamped to hard', () {
        final plan = resolveFdSoftLimitPlan(
          softBefore: 256,
          hardBefore: 4096,
          target: 10240,
        );
        expect(plan.alreadySatisfied, isFalse);
        expect(plan.newSoft, 4096);
      });

      test('target equal to hard still takes target (no off-by-one)', () {
        final plan = resolveFdSoftLimitPlan(
          softBefore: 256,
          hardBefore: 10240,
          target: 10240,
        );
        expect(plan.alreadySatisfied, isFalse);
        // target == hardBefore: `target < hardBefore` is false, so we pick
        // hardBefore. Either choice yields 10240; verify we settle on one.
        expect(plan.newSoft, 10240);
      });

      // -----------------------------------------------------------------------
      // Glados properties for the clamping arithmetic
      //
      // The discrete examples above pin the named branches; these properties
      // exercise the same branches across the whole integer space so a regressed
      // comparison (`<` vs `<=`, swapped operands) is caught regardless of the
      // particular magnitudes involved.
      // -----------------------------------------------------------------------
      glados.Glados(
        glados.any.fdClampCase,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'soft below target and target above a positive hard clamps to hard',
        (c) {
          final plan = resolveFdSoftLimitPlan(
            softBefore: c.softBefore,
            hardBefore: c.hardBefore,
            target: c.target,
          );
          expect(plan.alreadySatisfied, isFalse, reason: '$c');
          // Invariant under test: when the hard limit is the binding cap, the
          // new soft limit is exactly the hard limit — never the (larger)
          // target, and never an arbitrary value.
          expect(plan.newSoft, c.hardBefore, reason: '$c');
          // The result must never exceed the hard cap.
          expect(plan.newSoft, lessThanOrEqualTo(c.hardBefore), reason: '$c');
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.fdTargetFitsCase,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'soft below target with hard headroom raises exactly to target',
        (c) {
          final plan = resolveFdSoftLimitPlan(
            softBefore: c.softBefore,
            hardBefore: c.hardBefore,
            target: c.target,
          );
          expect(plan.alreadySatisfied, isFalse, reason: '$c');
          expect(plan.newSoft, c.target, reason: '$c');
          // Honouring the target must never breach the hard cap.
          expect(plan.newSoft, lessThanOrEqualTo(c.hardBefore), reason: '$c');
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.fdSatisfiedCase,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'soft at or above target is satisfied and left untouched',
        (c) {
          final plan = resolveFdSoftLimitPlan(
            softBefore: c.softBefore,
            hardBefore: c.hardBefore,
            target: c.target,
          );
          expect(plan.alreadySatisfied, isTrue, reason: '$c');
          // A satisfied soft limit must be returned verbatim — never lowered.
          expect(plan.newSoft, c.softBefore, reason: '$c');
        },
        tags: 'glados',
      );

      glados.Glados(
        glados.any.fdUnlimitedSoftCase,
        glados.ExploreConfig(numRuns: 96),
      ).test(
        'a negative (RLIM_INFINITY) soft limit is always satisfied, '
        'never lowered to target',
        (c) {
          final plan = resolveFdSoftLimitPlan(
            softBefore: c.softBefore,
            hardBefore: c.hardBefore,
            target: c.target,
          );
          expect(plan.alreadySatisfied, isTrue, reason: '$c');
          // The negative reading is preserved, not clobbered with target.
          expect(plan.newSoft, c.softBefore, reason: '$c');
          expect(plan.newSoft, isNegative, reason: '$c');
        },
        tags: 'glados',
      );
    });

    test('FdLimitAdjustment exposes all fields as provided', () {
      const adjustment = FdLimitAdjustment(
        softBefore: 256,
        hardBefore: 65536,
        softAfter: 10240,
        hardAfter: 65536,
        target: 10240,
        raised: true,
      );
      expect(adjustment.softBefore, 256);
      expect(adjustment.hardBefore, 65536);
      expect(adjustment.softAfter, 10240);
      expect(adjustment.hardAfter, 65536);
      expect(adjustment.target, 10240);
      expect(adjustment.raised, isTrue);
      expect(adjustment.error, isNull);
      expect(adjustment.toString(), contains('soft 256 -> 10240'));
      expect(adjustment.toString(), contains('raised=true'));
    });
  });

  group('readFileDescriptorLimits', () {
    test('returns non-null soft/hard pair on macOS or Linux', () {
      if (!Platform.isMacOS && !Platform.isLinux) return;
      final limits = readFileDescriptorLimits();
      expect(limits, isNotNull);
      expect(limits!.soft, greaterThan(0));
      expect(limits.hard, greaterThan(0));
      expect(limits.soft, lessThanOrEqualTo(limits.hard));
    });

    test(
      'after ensureFileDescriptorSoftLimit, soft reflects the raised value',
      () {
        if (!Platform.isMacOS && !Platform.isLinux) return;
        final adjustment = ensureFileDescriptorSoftLimit();
        final limits = readFileDescriptorLimits();
        expect(limits, isNotNull);
        expect(limits!.soft, adjustment.softAfter);
      },
    );
  });
}

/// A generated `(softBefore, hardBefore, target)` triple for one branch of
/// [resolveFdSoftLimitPlan]. The raw generator seeds are reshaped into the
/// ordering each scenario requires, so the property body never has to filter.
class _FdPlanCase {
  const _FdPlanCase({
    required this.softBefore,
    required this.hardBefore,
    required this.target,
  });

  final int softBefore;
  final int hardBefore;
  final int target;

  @override
  String toString() =>
      '_FdPlanCase(softBefore: $softBefore, hardBefore: $hardBefore, '
      'target: $target)';
}

extension _AnyFdPlan on glados.Any {
  // hard ∈ [1, 9999]; soft ∈ [0, hard) so soft < hard; target = hard + extra
  // (extra ≥ 1) so target > hard ≥ soft. The hard limit is the binding cap.
  glados.Generator<_FdPlanCase> get fdClampCase =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(1, 10000),
        (int hard, int softSeed, int targetExtra) => _FdPlanCase(
          hardBefore: hard,
          softBefore: softSeed % hard,
          target: hard + targetExtra,
        ),
      );

  // target ∈ [1, 9999]; hard = target + extra (extra ≥ 0) so hard ≥ target;
  // soft ∈ [0, target) so soft < target. The target fits under the hard cap.
  glados.Generator<_FdPlanCase> get fdTargetFitsCase =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        (int target, int hardExtra, int softSeed) => _FdPlanCase(
          target: target,
          hardBefore: target + hardExtra,
          softBefore: softSeed % target,
        ),
      );

  // target ∈ [1, 9999]; soft = target + extra (extra ≥ 0) so soft ≥ target;
  // hard is unconstrained — the soft limit already satisfies the target.
  glados.Generator<_FdPlanCase> get fdSatisfiedCase =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 10000),
        glados.IntAnys(this).intInRange(0, 10000),
        glados.IntAnys(this).intInRange(0, 100000),
        (int target, int softExtra, int hard) => _FdPlanCase(
          target: target,
          softBefore: target + softExtra,
          hardBefore: hard,
        ),
      );

  // soft = -seed (seed ≥ 1) so soft is negative — a Linux RLIM_INFINITY
  // readback. target and hard are arbitrary positive values.
  glados.Generator<_FdPlanCase> get fdUnlimitedSoftCase =>
      glados.CombinableAny(this).combine3(
        glados.IntAnys(this).intInRange(1, 1000),
        glados.IntAnys(this).intInRange(0, 100000),
        glados.IntAnys(this).intInRange(0, 100000),
        (int softSeed, int target, int hard) => _FdPlanCase(
          softBefore: -softSeed,
          target: target,
          hardBefore: hard,
        ),
      );
}
