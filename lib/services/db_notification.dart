import 'dart:async';

class UpdateNotifications {
  UpdateNotifications();

  final _controller = StreamController<Set<String>>.broadcast();
  final _localController = StreamController<Set<String>>.broadcast();
  final _affectedIds = <String>{};
  final _affectedIdsFromSync = <String>{};
  Timer? _timer;
  Timer? _fromSyncTimer;
  bool _isDisposed = false;

  /// Stream of all update notifications (both local and sync-originated).
  ///
  /// Used by UI widgets and other consumers that need to react to all changes.
  Stream<Set<String>> get updateStream => _controller.stream;

  /// Stream of only locally-originated update notifications.
  ///
  /// Used by agent wake orchestration so that sync-originated changes do not
  /// trigger agent wakes — the source device already ran the agent.
  Stream<Set<String>> get localUpdateStream => _localController.stream;

  void notify(Set<String> affectedIds, {bool fromSync = false}) {
    if (_isDisposed) return;

    if (fromSync) {
      _affectedIdsFromSync.addAll(affectedIds);
      _fromSyncTimer ??= Timer(const Duration(seconds: 1), () {
        if (_affectedIdsFromSync.isNotEmpty) {
          _controller.add({..._affectedIdsFromSync});
          _affectedIdsFromSync.clear();
        }
        _fromSyncTimer = null;
      });
    } else {
      _affectedIds.addAll(affectedIds);

      _timer ??= Timer(const Duration(milliseconds: 100), () {
        if (_affectedIds.isNotEmpty) {
          final batch = {..._affectedIds};
          _controller.add(batch);
          _localController.add(batch);
          _affectedIds.clear();
        }
        _timer = null;
      });
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    _fromSyncTimer?.cancel();
    _fromSyncTimer = null;
    _affectedIds.clear();
    _affectedIdsFromSync.clear();
    await _controller.close();
    await _localController.close();
  }
}

const habitCompletionNotification = 'HABIT_COMPLETION';
const textEntryNotification = 'TEXT_ENTRY';
const taskNotification = 'TASK';
const surveyNotification = 'SURVEY';
const eventNotification = 'EVENT';
const audioNotification = 'AUDIO';
const imageNotification = 'IMAGE';
const workoutNotification = 'WORKOUT';
const aiResponseNotification = 'AI_RESPONSE';
const dayPlanNotification = 'DAY_PLAN';
const ratingNotification = 'RATING';
const categoriesNotification = 'CATEGORIES_CHANGED';
const habitsNotification = 'HABITS_CHANGED';
const dashboardsNotification = 'DASHBOARDS_CHANGED';
const measurablesNotification = 'MEASURABLES_CHANGED';
const labelsNotification = 'LABELS_CHANGED';
const tagsNotification = 'TAGS_CHANGED';
const settingsNotification = 'SETTINGS_CHANGED';
const privateToggleNotification = 'PRIVATE_FLAG_TOGGLED';
const labelUsageNotification = 'LABEL_USAGE_CHANGED';
const agentNotification = 'AGENT_CHANGED';
