import 'dart:async';

class UpdateNotifications {
  UpdateNotifications();

  final _controller = StreamController<Set<String>>.broadcast();

  Stream<Set<String>> get updateStream => _controller.stream;

  void notify(Set<String> affectedIds) => _controller.add(affectedIds);
}
