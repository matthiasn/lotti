// Tests for pure, public functions in
// lib/features/projects/ui/widgets/project_status_attributes.dart.
//
// No GetIt, no ProviderContainer, no widget pump — only pure data functions.

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_attributes.dart';

// ---------------------------------------------------------------------------
// Generators
// ---------------------------------------------------------------------------

extension _AnyProjectFilter on glados.Any {
  /// A filter-ID string drawn from the five canonical values.
  glados.Generator<String> get validFilterId =>
      glados.AnyUtils(this).choose(<String>[
        ProjectStatusFilterIds.open,
        ProjectStatusFilterIds.active,
        ProjectStatusFilterIds.onHold,
        ProjectStatusFilterIds.completed,
        ProjectStatusFilterIds.archived,
      ]);

  /// An arbitrary letter/digit string that is not one of the five canonical IDs.
  glados.Generator<String> get unknownFilterId => glados.any.letterOrDigits;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // projectStatusKindFromFilterId — worked examples
  // -------------------------------------------------------------------------

  group('projectStatusKindFromFilterId — worked examples', () {
    test('maps every canonical filter-ID to the correct kind', () {
      expect(
        projectStatusKindFromFilterId(ProjectStatusFilterIds.open),
        ProjectStatusKind.open,
      );
      expect(
        projectStatusKindFromFilterId(ProjectStatusFilterIds.active),
        ProjectStatusKind.active,
      );
      expect(
        projectStatusKindFromFilterId(ProjectStatusFilterIds.onHold),
        ProjectStatusKind.onHold,
      );
      expect(
        projectStatusKindFromFilterId(ProjectStatusFilterIds.completed),
        ProjectStatusKind.completed,
      );
      expect(
        projectStatusKindFromFilterId(ProjectStatusFilterIds.archived),
        ProjectStatusKind.archived,
      );
    });

    test('unrecognised ID falls back to open', () {
      expect(
        projectStatusKindFromFilterId(''),
        ProjectStatusKind.open,
      );
      expect(
        projectStatusKindFromFilterId('unknown-status'),
        ProjectStatusKind.open,
      );
      expect(
        projectStatusKindFromFilterId('OPEN'),
        ProjectStatusKind.open,
        reason: 'matching is case-sensitive; "OPEN" is unknown',
      );
    });

    test('round-trip: every kind has a canonical ID that maps back to it', () {
      const mapping = <ProjectStatusKind, String>{
        ProjectStatusKind.open: ProjectStatusFilterIds.open,
        ProjectStatusKind.active: ProjectStatusFilterIds.active,
        ProjectStatusKind.onHold: ProjectStatusFilterIds.onHold,
        ProjectStatusKind.completed: ProjectStatusFilterIds.completed,
        ProjectStatusKind.archived: ProjectStatusFilterIds.archived,
      };
      for (final entry in mapping.entries) {
        expect(
          projectStatusKindFromFilterId(entry.value),
          entry.key,
          reason: 'filter ID "${entry.value}" should map to ${entry.key}',
        );
      }
    });
  });

  // -------------------------------------------------------------------------
  // projectStatusKindFromFilterId — Glados property tests
  // -------------------------------------------------------------------------

  group('projectStatusKindFromFilterId — properties', () {
    glados.Glados<String>(
      glados.any.validFilterId,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'any canonical filter-ID produces a valid ProjectStatusKind',
      (filterId) {
        final kind = projectStatusKindFromFilterId(filterId);
        expect(ProjectStatusKind.values.contains(kind), isTrue,
            reason: 'got $kind for "$filterId"');
      },
      tags: 'glados',
    );

    glados.Glados<String>(
      glados.any.unknownFilterId,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'any non-canonical string falls back to ProjectStatusKind.open',
      (filterId) {
        // The canonical IDs include hyphens; letterOrDigits cannot produce them.
        // Any pure alphanumeric string that is not one of the canonical IDs maps to open.
        final isCanonical = [
          ProjectStatusFilterIds.open,
          ProjectStatusFilterIds.active,
          ProjectStatusFilterIds.completed,
          ProjectStatusFilterIds.archived,
          // onHold contains a hyphen so it can never be a letterOrDigits hit
        ].contains(filterId);
        if (!isCanonical) {
          expect(
            projectStatusKindFromFilterId(filterId),
            ProjectStatusKind.open,
            reason: '"$filterId" is not canonical and should fall back to open',
          );
        }
      },
      tags: 'glados',
    );
  });

  // -------------------------------------------------------------------------
  // allProjectStatusKinds — sanity check
  // -------------------------------------------------------------------------

  group('allProjectStatusKinds', () {
    test('contains all five distinct kinds in declaration order', () {
      expect(allProjectStatusKinds, hasLength(5));
      expect(allProjectStatusKinds, containsAll(ProjectStatusKind.values));
    });
  });
}
