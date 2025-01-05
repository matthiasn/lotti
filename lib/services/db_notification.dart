import 'dart:async';

class UpdateNotifications {
  UpdateNotifications();

  final _controller = StreamController<Set<String>>.broadcast();
  final _affectedIds = <String>{};
  final _affectedIdsFromSync = <String>{};
  Timer? _timer;
  Timer? _fromSyncTimer;

  Stream<Set<String>> get updateStream => _controller.stream;

  void notify(Set<String> affectedIds, {bool fromSync = false}) {
    if (fromSync) {
      _affectedIdsFromSync.addAll(affectedIds);
      _fromSyncTimer ??= Timer(const Duration(seconds: 2), () {
        if (_affectedIdsFromSync.isNotEmpty) {
          _controller.add({..._affectedIdsFromSync});
          _affectedIdsFromSync.clear();
        }
        _fromSyncTimer = null;
      });
    } else {
      _affectedIds.addAll(affectedIds);

      _timer ??= Timer(const Duration(milliseconds: 50), () {
        if (_affectedIds.isNotEmpty) {
          _controller.add({..._affectedIds});
          _affectedIds.clear();
        }
        _timer = null;
      });
    }
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
