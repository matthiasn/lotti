import 'dart:async';

class UpdateNotifications {
  UpdateNotifications();

  final _controller = StreamController<Set<String>>.broadcast();
  final _affectedIds = <String>{};
  Timer? _timer;

  Stream<Set<String>> get updateStream => _controller.stream;

  void notify(Set<String> affectedIds) {
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
