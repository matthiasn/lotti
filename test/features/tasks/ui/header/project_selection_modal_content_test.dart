import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/callouts/design_system_inline_callout.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/header/project_selection_modal_content.dart';
import 'package:lotti/providers/project_lookup_providers.dart';
import 'package:lotti/widgets/picker/entity_picker_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../../projects/test_utils.dart';

/// The project picker is the project adapter over [EntityPickerSheet]; the
/// generic sheet (search debounce, create flow, Enter handling) is covered in
/// `test/widgets/picker/entity_picker_sheet_test.dart`. These tests cover the
/// adapter's own rules: which rows it emits for a query, what a pick writes,
/// and what happens when the write is refused.
void main() {
  const categoryId = 'cat-modal-1';
  const rejectedMessage =
      "Could not change this task's project. Check its category and "
      'privacy, then try again.';

  setUpAll(registerAllFallbackValues);

  ProjectEntry project(String id, String title, {bool? private}) {
    final entry = makeTestProject(
      id: id,
      title: title,
      categoryId: categoryId,
    );
    if (private == null) return entry;
    return entry.copyWith(meta: entry.meta.copyWith(private: private));
  }

  final alpha = project('p-alpha', 'Alpha');
  final beta = project('p-beta', 'Beta');
  final alpine = project('p-alpine', 'Alpine');

  Finder row(String key) => find.byKey(ValueKey(key));
  DesignSystemSelectionRow rowWidget(WidgetTester tester, String key) =>
      tester.widget<DesignSystemSelectionRow>(row(key));
  final noneRow = row('project-none');
  final searchField = find.byType(TextField);

  /// Pumps [ProjectSelectionModalContent] with the category provider answering
  /// through [loadProjects].
  Future<void> pumpContent(
    WidgetTester tester, {
    required Future<List<ProjectEntry>> Function() loadProjects,
    bool taskIsPrivate = false,
    String? currentProjectId,
    Future<bool> Function(ProjectEntry? project)? onProjectSelected,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ProjectSelectionModalContent(
            categoryId: categoryId,
            taskIsPrivate: taskIsPrivate,
            onProjectSelected: onProjectSelected ?? (_) async => true,
            currentProjectId: currentProjectId,
          ),
        ),
        overrides: [
          projectsForCategoryProvider(
            categoryId,
          ).overrideWith((ref) => loadProjects()),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  /// Pumps the body directly, for the states that never pop.
  Future<void> pumpBody(
    WidgetTester tester, {
    required AsyncValue<List<ProjectEntry>> projectsAsync,
    String? currentProjectId,
    Future<bool> Function(ProjectEntry? project)? onProjectSelected,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Scaffold(
          body: ProjectSelectionModalBody(
            projectsAsync: projectsAsync,
            onProjectSelected: onProjectSelected ?? (_) async => true,
            currentProjectId: currentProjectId,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Pushes the body on top of a base page, so a pick that closes the picker
  /// is observable as the body leaving the tree.
  Future<void> pumpPushedBody(
    WidgetTester tester, {
    required List<ProjectEntry> projects,
    required Future<bool> Function(ProjectEntry? project) onProjectSelected,
    String? currentProjectId,
  }) async {
    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      body: ProjectSelectionModalBody(
                        projectsAsync: AsyncData(projects),
                        onProjectSelected: onProjectSelected,
                        currentProjectId: currentProjectId,
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectSelectionModalBody), findsOneWidget);
  }

  Future<void> search(WidgetTester tester, String query) async {
    await tester.enterText(searchField, query);
    await tester.pump();
  }

  group('ProjectSelectionModalContent', () {
    testWidgets('a public task sees public projects only', (tester) async {
      await pumpContent(
        tester,
        loadProjects: () async => [
          project('p-public', 'Public', private: false),
          project('p-legacy', 'Legacy'),
          project('p-private', 'Private', private: true),
        ],
      );

      // A missing privacy flag is public, the same normalization the
      // repository applies when it checks a link.
      expect(find.text('Public'), findsOneWidget);
      expect(find.text('Legacy'), findsOneWidget);
      expect(find.text('Private'), findsNothing);
    });

    testWidgets('a private task sees private projects only', (tester) async {
      await pumpContent(
        tester,
        taskIsPrivate: true,
        loadProjects: () async => [
          project('p-public', 'Public', private: false),
          project('p-legacy', 'Legacy'),
          project('p-private', 'Private', private: true),
        ],
      );

      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Public'), findsNothing);
      expect(find.text('Legacy'), findsNothing);
    });

    testWidgets('shows a loading state while projects resolve', (tester) async {
      final pending = Completer<List<ProjectEntry>>();
      await pumpContent(tester, loadProjects: () => pending.future);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(EntityPickerSheet), findsNothing);
    });

    /// Pumps the content over a provider that re-runs on demand: [refresh]
    /// invalidates it (what a project notification does), [reload] changes a
    /// dependency it watches. The second run stays pending.
    Future<({void Function() refresh, void Function() reload})> pumpReloadable(
      WidgetTester tester,
    ) async {
      var version = 0;
      final dependency = Provider<int>((ref) => version);
      var loads = 0;
      final host = makeTestableWidgetWithContainer(
        Scaffold(
          body: ProjectSelectionModalContent(
            categoryId: categoryId,
            taskIsPrivate: false,
            onProjectSelected: (_) async => true,
          ),
        ),
        overrides: [
          projectsForCategoryProvider(categoryId).overrideWith((ref) {
            ref.watch(dependency);
            loads++;
            return loads == 1
                ? Future.value([alpha, beta])
                : Completer<List<ProjectEntry>>().future;
          }),
        ],
      );
      addTearDown(host.container.dispose);
      await tester.pumpWidget(host.widget);
      await tester.pump();
      await tester.pump();
      await search(tester, 'alp');
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      return (
        refresh: () =>
            host.container.invalidate(projectsForCategoryProvider(categoryId)),
        reload: () {
          version++;
          host.container.invalidate(dependency);
        },
      );
    }

    void expectRowsKept(WidgetTester tester) {
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      expect(tester.widget<TextField>(searchField).controller?.text, 'alp');
    }

    testWidgets('a refresh from a project notification keeps the rows and '
        'the typed query', (tester) async {
      // The pick's own link write fires a project notification, which
      // invalidates the provider while the picker is still up.
      final driver = await pumpReloadable(tester);

      driver.refresh();
      await tester.pump();
      await tester.pump();

      expectRowsKept(tester);
    });

    testWidgets('a reload from a dependency change keeps the rows instead of '
        'flashing a spinner', (tester) async {
      // A reload carries its previous value as a loading state, which the
      // content must map without dropping it.
      final driver = await pumpReloadable(tester);

      driver.reload();
      await tester.pump();
      await tester.pump();

      expectRowsKept(tester);
    });

    testWidgets('forwards the current project to the body', (tester) async {
      await pumpContent(
        tester,
        loadProjects: () async => [alpha, beta],
        currentProjectId: alpha.meta.id,
      );

      expect(rowWidget(tester, 'project-p-alpha').selected, isTrue);
      expect(rowWidget(tester, 'project-p-beta').selected, isFalse);
    });
  });

  group('states', () {
    testWidgets('shows a localized error when projects fail', (tester) async {
      await pumpBody(
        tester,
        projectsAsync: AsyncError(Exception('load failed'), StackTrace.current),
      );

      expect(find.text('Error loading projects'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(EntityPickerSheet), findsNothing);
    });

    testWidgets('an empty category says so instead of offering rows', (
      tester,
    ) async {
      await pumpBody(tester, projectsAsync: const AsyncData([]));

      expect(find.text('No projects yet'), findsOneWidget);
      expect(find.byType(DesignSystemSelectionRow), findsNothing);
      // The search field stays, as it does on every picker.
      expect(find.byType(DesignSystemSearch), findsOneWidget);
    });

    testWidgets(
      'an empty category still offers to unlink the project the task is in',
      (tester) async {
        // The task's project is not in the list — its privacy or category no
        // longer matches — so the only sensible move is to remove the link.
        await pumpBody(
          tester,
          projectsAsync: const AsyncData([]),
          currentProjectId: 'p-elsewhere',
        );

        expect(noneRow, findsOneWidget);
        expect(rowWidget(tester, 'project-none').selected, isFalse);
        expect(find.text('No projects yet'), findsNothing);
      },
    );
  });

  group('rows', () {
    testWidgets('uses the shared search field with the projects hint', (
      tester,
    ) async {
      await pumpBody(tester, projectsAsync: AsyncData([alpha]));

      expect(find.byType(DesignSystemSearch), findsOneWidget);
      expect(find.text('Search projects'), findsOneWidget);
    });

    testWidgets('lists every project with its title and status chip', (
      tester,
    ) async {
      await pumpBody(tester, projectsAsync: AsyncData([alpha, beta]));

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('Open'), findsNWidgets(2));
      expect(find.byType(DesignSystemSelectionRow), findsNWidgets(2));
      expect(find.byIcon(LottiIcons.folder), findsNWidgets(2));
    });

    testWidgets("folds the status into the row's accessible name", (
      tester,
    ) async {
      await pumpBody(tester, projectsAsync: AsyncData([alpha]));

      expect(rowWidget(tester, 'project-p-alpha').semanticLabel, 'Alpha, Open');
    });

    testWidgets('without a current project nothing is ticked and there is '
        'no No project row', (tester) async {
      await pumpBody(tester, projectsAsync: AsyncData([alpha, beta]));

      expect(noneRow, findsNothing);
      expect(find.byIcon(LottiIcons.block), findsNothing);
      expect(find.byIcon(LottiIcons.confirm), findsNothing);
      expect(rowWidget(tester, 'project-p-alpha').selected, isFalse);
      expect(rowWidget(tester, 'project-p-beta').selected, isFalse);
    });

    testWidgets('pins the current project first, ticked, with No project '
        'under it', (tester) async {
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpha, beta]),
        currentProjectId: beta.meta.id,
      );

      expect(rowWidget(tester, 'project-p-beta').selected, isTrue);
      expect(rowWidget(tester, 'project-p-alpha').selected, isFalse);
      expect(rowWidget(tester, 'project-none').selected, isFalse);
      expect(find.byIcon(LottiIcons.confirm), findsOneWidget);

      final betaTop = tester.getTopLeft(row('project-p-beta')).dy;
      final noneTop = tester.getTopLeft(noneRow).dy;
      final alphaTop = tester.getTopLeft(row('project-p-alpha')).dy;
      expect(betaTop, lessThan(noneTop));
      expect(noneTop, lessThan(alphaTop));
    });

    testWidgets('the pinned current project is listed once', (tester) async {
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpha, beta]),
        currentProjectId: alpha.meta.id,
      );

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.byType(DesignSystemSelectionRow), findsNWidgets(3));
    });
  });

  group('search', () {
    testWidgets('filters projects by title, ignoring case', (tester) async {
      await pumpBody(tester, projectsAsync: AsyncData([alpha, beta, alpine]));

      await search(tester, 'ALP');

      expect(find.text('Alpha'), findsOneWidget);
      expect(find.text('Alpine'), findsOneWidget);
      expect(find.text('Beta'), findsNothing);
    });

    testWidgets('a query with no match shows the shared empty message', (
      tester,
    ) async {
      await pumpBody(tester, projectsAsync: AsyncData([alpha, beta]));

      await search(tester, 'zeta');

      expect(find.text('No matches'), findsOneWidget);
      expect(find.text('No projects yet'), findsNothing);
      expect(find.byType(DesignSystemSelectionRow), findsNothing);
    });

    testWidgets('hides No project once the search drops the current project', (
      tester,
    ) async {
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpha, beta]),
        currentProjectId: alpha.meta.id,
      );
      expect(noneRow, findsOneWidget);

      await search(tester, 'beta');

      expect(noneRow, findsNothing);
      expect(find.text('Alpha'), findsNothing);
      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('keeps the current project pinned and No project beside it '
        'while it matches', (tester) async {
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpine, beta, alpha]),
        currentProjectId: alpha.meta.id,
      );

      await search(tester, 'alp');

      expect(rowWidget(tester, 'project-p-alpha').selected, isTrue);
      expect(noneRow, findsOneWidget);
      expect(find.text('Beta'), findsNothing);
      final alphaTop = tester.getTopLeft(row('project-p-alpha')).dy;
      final noneTop = tester.getTopLeft(noneRow).dy;
      final alpineTop = tester.getTopLeft(row('project-p-alpine')).dy;
      expect(alphaTop, lessThan(noneTop));
      expect(noneTop, lessThan(alpineTop));
    });

    testWidgets('clearing the query restores the full list', (tester) async {
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpha, beta]),
        currentProjectId: alpha.meta.id,
      );

      await search(tester, 'beta');
      expect(find.byType(DesignSystemSelectionRow), findsOneWidget);

      await search(tester, '');

      expect(find.byType(DesignSystemSelectionRow), findsNWidgets(3));
      expect(noneRow, findsOneWidget);
    });

    testWidgets('Enter picks the first match', (tester) async {
      ProjectEntry? picked;
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpha, beta]),
        onProjectSelected: (p) async {
          picked = p;
          return true;
        },
      );

      await search(tester, 'bet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(picked?.meta.id, beta.meta.id);
    });
  });

  group('picking', () {
    testWidgets('hands the tapped project to onProjectSelected and closes', (
      tester,
    ) async {
      ProjectEntry? picked;
      await pumpPushedBody(
        tester,
        projects: [alpha, beta],
        onProjectSelected: (p) async {
          picked = p;
          return true;
        },
      );

      await tester.tap(find.text('Beta'));
      await tester.pumpAndSettle();

      expect(picked?.meta.id, beta.meta.id);
      expect(find.byType(ProjectSelectionModalBody), findsNothing);
    });

    testWidgets('hands null to onProjectSelected when No project is tapped', (
      tester,
    ) async {
      var called = false;
      ProjectEntry? picked = alpha;
      await pumpPushedBody(
        tester,
        projects: [alpha],
        currentProjectId: alpha.meta.id,
        onProjectSelected: (p) async {
          called = true;
          picked = p;
          return true;
        },
      );

      await tester.tap(find.text('No project'));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(picked, isNull);
      expect(find.byType(ProjectSelectionModalBody), findsNothing);
    });

    testWidgets('a tap on the ticked current project closes without a write', (
      tester,
    ) async {
      var calls = 0;
      await pumpPushedBody(
        tester,
        projects: [alpha, beta],
        currentProjectId: alpha.meta.id,
        onProjectSelected: (_) async {
          calls++;
          return true;
        },
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(calls, 0);
      expect(find.byType(ProjectSelectionModalBody), findsNothing);
    });

    testWidgets('keeps the picker open and explains a rejected selection', (
      tester,
    ) async {
      await pumpPushedBody(
        tester,
        projects: [alpha],
        onProjectSelected: (_) async => false,
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpAndSettle();

      expect(find.byType(ProjectSelectionModalBody), findsOneWidget);
      expect(find.text('Alpha'), findsOneWidget);
      final callout = tester.widget<DesignSystemInlineCallout>(
        find.byKey(const ValueKey('project-picker-rejected')),
      );
      expect(callout.text, rejectedMessage);
      expect(callout.icon, LottiIcons.error);
      expect(callout.announce, isTrue);
      expect(find.text(rejectedMessage), findsOneWidget);
    });

    // The repository rejects asynchronously; a plain callback may throw
    // before it ever returns a future. Both land in the same catch.
    for (final (form, write)
        in <(String, Future<bool> Function(ProjectEntry?))>[
          (
            'rejects asynchronously',
            (_) async => throw StateError('sync changed'),
          ),
          ('throws synchronously', (_) => throw StateError('sync changed')),
        ]) {
      testWidgets('a write that $form is reported the same way', (
        tester,
      ) async {
        await pumpPushedBody(
          tester,
          projects: [alpha],
          onProjectSelected: write,
        );

        await tester.tap(find.text('Alpha'));
        await tester.pumpAndSettle();

        expect(find.byType(ProjectSelectionModalBody), findsOneWidget);
        expect(find.text(rejectedMessage), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a second tap while a write is in flight is ignored', (
      tester,
    ) async {
      final write = Completer<bool>();
      final picks = <String?>[];
      await pumpPushedBody(
        tester,
        projects: [alpha, beta],
        onProjectSelected: (p) {
          picks.add(p?.meta.id);
          return write.future;
        },
      );

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      await tester.tap(find.text('Beta'));
      await tester.pump();

      expect(picks, ['p-alpha']);

      write.complete(true);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectSelectionModalBody), findsNothing);
    });

    testWidgets('a retry clears the explanation while it runs and brings it '
        'back if refused again', (tester) async {
      final writes = <Completer<bool>>[];
      await pumpPushedBody(
        tester,
        projects: [alpha, beta],
        onProjectSelected: (_) {
          final write = Completer<bool>();
          writes.add(write);
          return write.future;
        },
      );

      await tester.tap(find.text('Alpha'));
      await tester.pump();
      writes.single.complete(false);
      await tester.pump();
      expect(find.text(rejectedMessage), findsOneWidget);

      await tester.tap(find.text('Beta'));
      await tester.pump();
      expect(find.text(rejectedMessage), findsNothing);

      writes.last.complete(false);
      await tester.pump();
      expect(writes, hasLength(2));
      expect(find.text(rejectedMessage), findsOneWidget);
    });

    testWidgets('does not pop after the content is unmounted mid-selection', (
      tester,
    ) async {
      final write = Completer<bool>();
      await pumpBody(
        tester,
        projectsAsync: AsyncData([alpha]),
        onProjectSelected: (_) => write.future,
      );

      await tester.tap(find.text('Alpha'));
      await tester.pumpWidget(const SizedBox.shrink());
      write.complete(true);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
