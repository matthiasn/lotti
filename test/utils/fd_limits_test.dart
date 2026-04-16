import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
