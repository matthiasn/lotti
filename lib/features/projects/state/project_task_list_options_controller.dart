import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/get_it.dart';

/// SettingsDb key prefix for a project's task-list grouping and ordering;
/// the project id follows it.
const projectTaskListOptionsSettingsKeyPrefix = 'PROJECT_TASK_LIST_OPTIONS_';

String projectTaskListOptionsSettingsKey(String projectId) =>
    '$projectTaskListOptionsSettingsKeyPrefix$projectId';

/// Remembers how one project's task list is grouped and ordered.
///
/// Loads once from [SettingsDb], holds the choice in memory and persists
/// every change. SettingsDb writes emit no `UpdateNotifications` token, so
/// the list must watch this provider rather than re-read the database. A
/// missing or unreadable preference yields the defaults; a still-in-flight
/// initial load never clobbers a choice the user has just made.
class ProjectTaskListOptionsController
    extends Notifier<ProjectTaskListOptions> {
  ProjectTaskListOptionsController(this.projectId);

  final String projectId;
  bool _edited = false;

  @override
  ProjectTaskListOptions build() {
    unawaited(_load());
    return ProjectTaskListOptions.defaults;
  }

  Future<void> _load() async {
    if (!getIt.isRegistered<SettingsDb>()) return;
    final raw = await getIt<SettingsDb>().itemByKey(
      projectTaskListOptionsSettingsKey(projectId),
    );
    if (!ref.mounted || _edited || raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        state = ProjectTaskListOptions.fromJson(decoded);
      }
    } on FormatException {
      // A corrupt preference is not worth surfacing; the defaults stand.
    }
  }

  /// Applies [options] and persists them.
  void update(ProjectTaskListOptions options) {
    _edited = true;
    state = options;
    if (!getIt.isRegistered<SettingsDb>()) return;
    unawaited(
      getIt<SettingsDb>().saveSettingsItem(
        projectTaskListOptionsSettingsKey(projectId),
        jsonEncode(options.toJson()),
      ),
    );
  }
}

/// The remembered grouping and ordering of one project's task list.
final NotifierProviderFamily<
  ProjectTaskListOptionsController,
  ProjectTaskListOptions,
  String
>
projectTaskListOptionsProvider =
    NotifierProvider.family<
      ProjectTaskListOptionsController,
      ProjectTaskListOptions,
      String
    >(
      ProjectTaskListOptionsController.new,
      name: 'projectTaskListOptionsProvider',
    );
