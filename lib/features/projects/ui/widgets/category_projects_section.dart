import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_chip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// Shows projects within a category on the category details page.
class CategoryProjectsSection extends ConsumerWidget {
  const CategoryProjectsSection({
    required this.categoryId,
    super.key,
  });

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsForCategoryProvider(categoryId));
    final messages = context.messages;

    return projectsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (List<ProjectEntry> projects) => LottiFormSection(
        title: messages.projectHealthTitle,
        icon: Icons.folder_outlined,
        children: [
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                messages.projectNoProjects,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...projects.map(
              (project) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined, size: 20),
                title: Text(
                  project.data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: ProjectStatusChip(status: project.data.status),
                onTap: () => getIt<NavService>().beamToNamed(
                  '/settings/projects/${project.meta.id}',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: LottiSecondaryButton(
              onPressed: () => getIt<NavService>().beamToNamed(
                '/settings/projects/create?categoryId=$categoryId',
              ),
              label: messages.projectCreateButton,
              icon: Icons.add,
            ),
          ),
        ],
      ),
    );
  }
}
