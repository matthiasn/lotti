import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/project_world_generator.dart';
import 'package:lotti/features/plaza/state/plaza_sky_mode_controller.dart';
import 'package:lotti/features/plaza/state/project_plaza_provider.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/features/plaza/ui/plaza_view.dart';
import 'package:lotti/features/tasks/ui/pages/task_details_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:material_ui/material_ui.dart';

/// Keeps the data/navigation boundary independently testable without a GPU.
typedef ProjectPlazaSceneBuilder =
    Widget Function({
      required PlazaWorld world,
      required ChecklistTicks ticks,
      required ValueChanged<PlazaTask> onOpenTask,
      required VoidCallback onExit,
      PlazaSkyMode initialSkyMode,
      ValueChanged<PlazaSkyMode>? onSkyModeChanged,
    });

/// A live project world. The current scene remains mounted across background
/// refreshes; the renderer preserves its camera when the snapshot changes.
class ProjectPlazaPage extends ConsumerStatefulWidget {
  const ProjectPlazaPage({
    required this.projectId,
    this.categoryId,
    this.sceneBuilder = PlazaView.new,
    super.key,
  });

  final String projectId;

  /// A category avenue never follows a project that sync moves out of scope.
  final String? categoryId;
  final ProjectPlazaSceneBuilder sceneBuilder;

  @override
  ConsumerState<ProjectPlazaPage> createState() => _ProjectPlazaPageState();
}

class _ProjectPlazaPageState extends ConsumerState<ProjectPlazaPage> {
  late final ChecklistTicks _ticks;
  ProjectPlazaData? _snapshot;
  PlazaWorld? _world;

  @override
  void initState() {
    super.initState();
    _ticks = ChecklistTicks(
      persist: (taskId, itemId, {required checked}) => ref
          .read(plazaRepositoryProvider)
          .setChecklistItemChecked(
            projectId: widget.projectId,
            taskId: taskId,
            itemId: itemId,
            checked: checked,
          ),
      onFailure: () {
        if (!mounted) return;
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.commonError,
        );
      },
    );
  }

  @override
  void didUpdateWidget(ProjectPlazaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.projectId != widget.projectId ||
        oldWidget.categoryId != widget.categoryId) {
      _snapshot = null;
      _world = null;
      _ticks.bindTasks(const []);
    }
  }

  @override
  void dispose() {
    _ticks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(projectPlazaProvider(widget.projectId));
    final now = ref.watch(plazaDayProvider);
    return Theme(
      data: DesignSystemTheme.dark(),
      child: data.when(
        skipLoadingOnReload: true,
        skipError: true,
        loading: () => _shell(
          const Center(child: CircularProgressIndicator.adaptive()),
        ),
        error: (_, _) => _shell(
          ErrorStateWidget(
            error: context.messages.commonError,
            mode: ErrorDisplayMode.inline,
          ),
        ),
        data: (snapshot) {
          if (snapshot == null ||
              (widget.categoryId != null &&
                  snapshot.project.meta.categoryId != widget.categoryId)) {
            _snapshot = null;
            _world = null;
            _ticks.bindTasks(const []);
            return _shell(
              Center(child: Text(context.messages.projectNotFound)),
            );
          }
          if (snapshot.tasks.isEmpty) {
            _snapshot = null;
            _world = null;
            _ticks.bindTasks(const []);
            return _shell(Center(child: Text(context.messages.plazaEmpty)));
          }
          if (!identical(snapshot, _snapshot) ||
              _world?.now != now ||
              _world?.copy.messages.localeName != context.messages.localeName) {
            _snapshot = snapshot;
            _ticks.bindTasks(snapshot.tasks);
            final category = snapshot.category;
            _world = generateProjectWorld(
              project: snapshot.project,
              tasks: snapshot.tasks,
              connections: snapshot.connections,
              now: now,
              copy: PlazaCopy(context.messages),
              categoryLabels: {
                if (category != null)
                  for (final task in snapshot.tasks)
                    task.categoryColor.toRadixString(16): category.name,
              },
            );
          }
          return widget.sceneBuilder(
            world: _world!,
            ticks: _ticks,
            onOpenTask: (task) => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => TaskDetailsPage(taskId: task.id),
              ),
            ),
            onExit: () => Navigator.of(context).pop(),
            initialSkyMode: ref.watch(plazaSkyModeProvider),
            onSkyModeChanged: ref.read(plazaSkyModeProvider.notifier).set,
          );
        },
      ),
    );
  }

  Widget _shell(Widget child) => Scaffold(
    appBar: AppBar(title: Text(context.messages.plazaTitle)),
    body: child,
  );
}
