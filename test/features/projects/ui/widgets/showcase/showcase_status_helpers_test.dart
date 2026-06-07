// Tests for the public functions in
// lib/features/projects/ui/widgets/showcase/showcase_status_helpers.dart.
//
// [showcaseFormatDuration] and [showcaseProjectStatusIcon] are pure.
// [showcaseProjectStatusLabel] and [showcaseProjectStatusColor] require
// BuildContext/l10n → those run inside a pumped widget below.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_status_helpers.dart';

import '../../../../../test_helper.dart';

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

extension _AnyDuration on glados.Any {
  /// Non-negative seconds spanning zero to well beyond one hour.
  glados.Generator<int> get durationSeconds => glados.any.intInRange(0, 7200);

  /// Non-negative minutes to build Duration objects for the minute-path.
  glados.Generator<int> get durationMinutes => glados.any.intInRange(0, 120);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('showcase project status helpers', () {
    final testDate = DateTime(2026, 3, 15, 10);
    final statusesByKind = {
      for (final kind in ProjectStatusKind.values)
        kind: buildProjectStatus(kind, testDate),
    };

    test('icon is distinct per status variant', () {
      const expectedIcons = <ProjectStatusKind, IconData>{
        ProjectStatusKind.open: Icons.radio_button_unchecked_rounded,
        ProjectStatusKind.active: Icons.play_arrow_rounded,
        ProjectStatusKind.monitoring: Icons.visibility_outlined,
        ProjectStatusKind.onHold: Icons.pause_circle_outline_rounded,
        ProjectStatusKind.completed: Icons.check_circle_outline_rounded,
        ProjectStatusKind.archived: Icons.archive_outlined,
      };
      expect(expectedIcons.keys, containsAll(ProjectStatusKind.values));

      for (final entry in statusesByKind.entries) {
        expect(
          showcaseProjectStatusIcon(entry.value),
          expectedIcons[entry.key],
          reason: '${entry.key}',
        );
      }
    });

    testWidgets('label and color resolve for every status variant', (
      tester,
    ) async {
      const expectedLabels = <ProjectStatusKind, String>{
        ProjectStatusKind.open: 'Open',
        ProjectStatusKind.active: 'Active',
        ProjectStatusKind.monitoring: 'Monitoring',
        ProjectStatusKind.onHold: 'On Hold',
        ProjectStatusKind.completed: 'Completed',
        ProjectStatusKind.archived: 'Archived',
      };
      expect(expectedLabels.keys, containsAll(ProjectStatusKind.values));

      late BuildContext capturedContext;
      await tester.pumpWidget(
        WidgetTestBench(
          child: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final colors = <Color>[];
      for (final entry in statusesByKind.entries) {
        expect(
          showcaseProjectStatusLabel(capturedContext, entry.value),
          expectedLabels[entry.key],
          reason: '${entry.key}',
        );
        colors.add(showcaseProjectStatusColor(capturedContext, entry.value));
      }
      // Every variant resolves to a concrete color (no throw, no null).
      expect(colors, hasLength(ProjectStatusKind.values.length));
      // The new monitoring variant maps to the showcase teal, distinct from
      // its neighbours (active=amber, completed=timeGreen).
      expect(
        showcaseProjectStatusColor(
          capturedContext,
          statusesByKind[ProjectStatusKind.monitoring]!,
        ),
        ShowcasePalette.teal(capturedContext),
      );
    });
  });

  // -------------------------------------------------------------------------
  // showcaseFormatDuration — worked examples (all branches)
  // -------------------------------------------------------------------------

  group('showcaseFormatDuration — worked examples', () {
    test('zero duration yields 0s', () {
      expect(showcaseFormatDuration(Duration.zero), '0s');
    });

    test('seconds-only path (< 1 minute)', () {
      expect(showcaseFormatDuration(const Duration(seconds: 1)), '1s');
      expect(showcaseFormatDuration(const Duration(seconds: 45)), '45s');
      expect(showcaseFormatDuration(const Duration(seconds: 59)), '59s');
    });

    test('exact minute — no fractional seconds — yields Nm', () {
      expect(showcaseFormatDuration(const Duration(minutes: 1)), '1m');
      expect(showcaseFormatDuration(const Duration(minutes: 5)), '5m');
      expect(showcaseFormatDuration(const Duration(minutes: 59)), '59m');
    });

    test('minutes and seconds both present yields Nm Ns', () {
      expect(
        showcaseFormatDuration(const Duration(minutes: 1, seconds: 30)),
        '1m 30s',
      );
      expect(
        showcaseFormatDuration(const Duration(minutes: 2, seconds: 5)),
        '2m 5s',
      );
    });

    test(
      'hour path yields Nh Nm (seconds are dropped at hour granularity)',
      () {
        expect(
          showcaseFormatDuration(const Duration(hours: 1)),
          '1h 0m',
        );
        expect(
          showcaseFormatDuration(const Duration(hours: 2, minutes: 15)),
          '2h 15m',
        );
        expect(
          showcaseFormatDuration(
            const Duration(hours: 1, minutes: 30, seconds: 45),
          ),
          '1h 30m',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // showcaseFormatDuration — Glados property tests
  // -------------------------------------------------------------------------

  group('showcaseFormatDuration — properties', () {
    glados.Glados<int>(
      glados.any.durationSeconds,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result is never empty for any non-negative Duration',
      (seconds) {
        final result = showcaseFormatDuration(Duration(seconds: seconds));
        expect(result, isNotEmpty);
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.durationSeconds,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result always ends with a letter suffix (h, m, or s)',
      (seconds) {
        final result = showcaseFormatDuration(Duration(seconds: seconds));
        // The last character must be h, m, or s.
        expect(
          ['h', 'm', 's'].contains(result[result.length - 1]),
          isTrue,
          reason: '"$result" does not end with h, m, or s',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(0, 60),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'durations under one minute always end with s (seconds suffix)',
      (seconds) {
        final result = showcaseFormatDuration(Duration(seconds: seconds));
        expect(
          result.endsWith('s'),
          isTrue,
          reason: '"$result" should end with s for ${seconds}s duration',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.intInRange(3600, 7200),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'durations of at least one hour always end with m (minute suffix)',
      (seconds) {
        final result = showcaseFormatDuration(Duration(seconds: seconds));
        expect(
          result.endsWith('m'),
          isTrue,
          reason: '"$result" should end with m for ${seconds}s duration',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.durationSeconds,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'output round-trips to the input seconds truncated at the displayed '
      'granularity',
      (seconds) {
        final result = showcaseFormatDuration(Duration(seconds: seconds));

        // Independent parser: sum up each `<number><unit>` token.
        var parsedSeconds = 0;
        for (final token in result.split(' ')) {
          final value = int.parse(token.substring(0, token.length - 1));
          parsedSeconds += switch (token[token.length - 1]) {
            'h' => value * 3600,
            'm' => value * 60,
            _ => value,
          };
        }

        // Hour-granularity output drops seconds; everything else is exact.
        final granularity = seconds >= 3600 ? 60 : 1;
        expect(
          parsedSeconds,
          seconds - seconds % granularity,
          reason: '"$result" should round-trip from $seconds s',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.any.durationMinutes,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'exact multiples of 60 seconds produce a result ending with m not s',
      (minutes) {
        final result = showcaseFormatDuration(Duration(minutes: minutes));
        if (minutes == 0) {
          expect(
            result.endsWith('s'),
            isTrue,
            reason: '0 minutes = 0 seconds → should end with s',
          );
        } else if (minutes < 60) {
          expect(
            result.endsWith('m'),
            isTrue,
            reason: '$minutes min (exact) should end with m',
          );
        } else {
          expect(
            result.endsWith('m'),
            isTrue,
            reason: '$minutes min >= 60 should end with m',
          );
        }
      },
      tags: 'glados',
    );
  });
}
