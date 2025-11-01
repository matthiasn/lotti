import 'package:fake_async/fake_async.dart';

extension FakeAsyncX on FakeAsync {
  void elapseAndFlush(Duration duration) {
    elapse(duration);
    flushMicrotasks();
  }
}
