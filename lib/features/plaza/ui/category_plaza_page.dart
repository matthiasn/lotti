import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/plaza/data/plaza_repository.dart';
import 'package:lotti/features/plaza/scene/category_world_generator.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/state/plaza_sky_mode_controller.dart';
import 'package:lotti/features/plaza/state/project_plaza_provider.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/features/plaza/ui/plaza_view.dart';
import 'package:lotti/features/plaza/ui/project_plaza_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:material_ui/material_ui.dart';

/// Category-scoped avenues. A portal opens one project's full world on top of
/// this route, so Back returns to the same category camera and search state.
class CategoryPlazaPage extends ConsumerStatefulWidget {
  const CategoryPlazaPage({
    required this.categoryId,
    this.sceneBuilder = PlazaView.new,
    super.key,
  });

  final String categoryId;
  final ProjectPlazaSceneBuilder sceneBuilder;

  @override
  ConsumerState<CategoryPlazaPage> createState() => _CategoryPlazaPageState();
}

class _CategoryPlazaPageState extends ConsumerState<CategoryPlazaPage> {
  final _ticks = ChecklistTicks();
  CategoryPlazaData? _snapshot;
  PlazaWorld? _world;

  @override
  void didUpdateWidget(CategoryPlazaPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categoryId != widget.categoryId) _clear();
  }

  void _clear() {
    _snapshot = null;
    _world = null;
    _ticks.bindTasks(const []);
  }

  @override
  void dispose() {
    _ticks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(categoryPlazaProvider(widget.categoryId));
    final now = ref.watch(plazaDayProvider);
    return Theme(
      data: DesignSystemTheme.dark(),
      child: data.when(
        skipLoadingOnReload: true,
        skipError: true,
        loading: () =>
            _shell(const Center(child: CircularProgressIndicator.adaptive())),
        error: (_, _) => _shell(
          ErrorStateWidget(
            error: context.messages.commonError,
            mode: ErrorDisplayMode.inline,
          ),
        ),
        data: (snapshot) {
          if (snapshot == null ||
              snapshot.category.id != widget.categoryId ||
              snapshot.projects.isEmpty) {
            _clear();
            return _shell(
              Center(child: Text(context.messages.plazaCategoryEmpty)),
            );
          }
          if (!identical(snapshot, _snapshot) ||
              _world?.now != now ||
              _world?.copy.messages.localeName != context.messages.localeName) {
            _snapshot = snapshot;
            _world = generateCategoryWorld(
              data: snapshot,
              now: now,
              copy: PlazaCopy(context.messages),
            );
          }
          return widget.sceneBuilder(
            world: _world!,
            ticks: _ticks,
            onOpenTask: (portal) {
              if (portal.project == null ||
                  _world?.avenueByProjectId.containsKey(portal.id) != true) {
                return;
              }
              Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => ProjectPlazaPage(
                    projectId: portal.id,
                    categoryId: widget.categoryId,
                    sceneBuilder: widget.sceneBuilder,
                  ),
                ),
              );
            },
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
