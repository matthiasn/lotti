// Throwaway screenshot-capture test for the Project Details page design review.
// Renders a populated ProjectDetailsPage at phone + desktop. Delete after use.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/project_data.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/projects/state/project_detail_controller.dart';
import 'package:lotti/features/projects/state/project_detail_record_provider.dart';
import 'package:lotti/features/projects/state/project_health_metrics.dart';
import 'package:lotti/features/projects/ui/model/project_list_detail_models.dart';
import 'package:lotti/features/projects/ui/pages/project_details_page.dart';

import 'features/categories/test_utils.dart';
import 'features/projects/test_utils.dart';
import 'test_utils/screenshot_harness.dart';

const _projectId = 'device-sync';
final _t = DateTime(2026, 3, 15);
final _now = DateTime(2026, 6, 24, 9, 30);

class _TestProjectDetailController extends ProjectDetailController {
  _TestProjectDetailController(this._state) : super(_projectId);

  final ProjectDetailState _state;

  @override
  ProjectDetailState build() => _state;

  @override
  void updateTitle(String title) {}

  @override
  void updateTargetDate(DateTime? targetDate) {}

  @override
  void updateCategoryId(String? categoryId) {}

  @override
  void updateStatus(ProjectStatus newStatus) {}

  @override
  Future<void> saveChanges() async {}
}

Task _task(String id, String title, TaskStatus status) =>
    JournalEntity.task(
          meta: Metadata(
            id: id,
            createdAt: _t,
            updatedAt: _t,
            dateFrom: _t,
            dateTo: _t,
            vectorClock: null,
          ),
          data: TaskData(
            title: title,
            status: status,
            statusHistory: const [],
            dateFrom: _t,
            dateTo: _t,
          ),
          entryText: const EntryText(plainText: ''),
        )
        as Task;

TaskStatus _done() => TaskStatus.done(id: 'd', createdAt: _t, utcOffset: 0);
TaskStatus _inProgress() =>
    TaskStatus.inProgress(id: 'p', createdAt: _t, utcOffset: 0);
TaskStatus _open() => TaskStatus.open(id: 'o', createdAt: _t, utcOffset: 0);
TaskStatus _blocked() => TaskStatus.blocked(
  id: 'b',
  createdAt: _t,
  utcOffset: 0,
  reason: 'waiting on vendor',
);

final _work = CategoryTestUtils.createTestCategory(
  id: 'work',
  name: 'Work',
  color: '#B07CF0',
);

final _project = makeTestProject(
  id: _projectId,
  title: 'Device Sync v2',
  status: ProjectStatus.active(id: 's', createdAt: _t, utcOffset: 0),
  categoryId: 'work',
  targetDate: DateTime(2026, 7, 4),
  createdAt: _t,
);

ProjectRecord _record() => makeTestProjectRecord(
  project: _project,
  category: _work,
  healthScore: 78,
  healthMetrics: makeTestProjectHealthMetrics(
    band: ProjectHealthBand.onTrack,
    rationale: 'Steady progress; two integration tasks remain before beta.',
    confidence: 0.9,
  ),
  completedTaskCount: 3,
  totalTaskCount: 8,
  blockedTaskCount: 1,
  aiSummary:
      'End-to-end encrypted multi-device sync is on track. Conflict '
      'resolution and the migration path are done; two integration tasks '
      'remain before the closed beta.',
  reportContent:
      '# Status\n\nEnd-to-end encrypted multi-device sync is on track. '
      'Conflict resolution and the v1 migration path have landed and are '
      'covered by tests.\n\n## Remaining\n\n- Device pairing polish\n- '
      'Background sync scheduler\n\nThe vendor schema export is the only '
      'external dependency still outstanding.',
  recommendations: [
    'Finalize the conflict-resolution spec with the platform team',
    'Schedule the closed-beta rollout review for early July',
  ],
  reportUpdatedAt: DateTime(2026, 6, 23, 18),
  highlightedTaskSummaries: [
    makeTestTaskSummary(
      task: _task('t1', 'Conflict resolution engine', _done()),
      estimatedDuration: const Duration(hours: 6),
      oneLiner: 'Merge strategy shipped and covered by tests',
    ),
    makeTestTaskSummary(
      task: _task('t2', 'Device pairing flow', _inProgress()),
      estimatedDuration: const Duration(hours: 4),
      oneLiner: 'QR and numeric fallback wired; polishing error states',
    ),
    makeTestTaskSummary(
      task: _task('t3', 'Migration from the v1 store', _blocked()),
      estimatedDuration: const Duration(hours: 8),
      oneLiner: 'Blocked on the vendor schema export',
    ),
    makeTestTaskSummary(
      task: _task('t4', 'Background sync scheduler', _inProgress()),
      estimatedDuration: const Duration(hours: 5),
      oneLiner: 'Batching and backoff implemented; tuning intervals',
    ),
    makeTestTaskSummary(
      task: _task('t5', 'Encrypted key rotation', _open()),
      estimatedDuration: const Duration(hours: 6),
      oneLiner: null,
    ),
    makeTestTaskSummary(
      task: _task('t6', 'Telemetry & sync metrics', _open()),
      estimatedDuration: const Duration(hours: 3),
      oneLiner: 'Define the dashboards before the beta opens',
    ),
    makeTestTaskSummary(
      task: _task('t7', 'Threat model review', _done()),
      estimatedDuration: const Duration(hours: 4),
      oneLiner: 'Signed off with security; no blockers found',
    ),
    makeTestTaskSummary(
      task: _task('t8', 'Protocol spec draft', _done()),
      estimatedDuration: const Duration(hours: 5),
      oneLiner: 'Versioned wire format documented',
    ),
  ],
  highlightedTasksTotalDuration: const Duration(hours: 41),
);

List<Override> _overrides() => [
  projectDetailControllerProvider(_projectId).overrideWith(
    () => _TestProjectDetailController(
      ProjectDetailState(
        project: _project,
        linkedTasks: const [],
        isLoading: false,
        isSaving: false,
        hasChanges: false,
      ),
    ),
  ),
  projectDetailRecordProvider(_projectId).overrideWith((ref) => _record()),
  projectDetailNowProvider.overrideWithValue(() => _now),
  projectAgentProvider(_projectId).overrideWith((ref) async => null),
  agentIsRunningProvider.overrideWith((ref, agentId) => Stream.value(false)),
];

void main() {
  setUpAll(loadAppFonts);

  testWidgets('project details baseline — phone', (tester) async {
    await captureInApp(
      tester,
      child: const ProjectDetailsPage(projectId: _projectId),
      name: 'project_details_baseline_phone',
      overrides: _overrides(),
    );
  });

  testWidgets('project details baseline — desktop', (tester) async {
    await captureInApp(
      tester,
      child: const ProjectDetailsPage(projectId: _projectId),
      name: 'project_details_baseline_desktop',
      size: ScreenshotViewport.desktop,
      overrides: _overrides(),
    );
  });
}
