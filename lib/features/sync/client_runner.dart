import 'dart:async';

/// Creates a runner object that provides a queue of requests for calling
/// the provided async callback, one at a time, without requiring a mutex.
/// Requests on the queue are handled FIFO, enqueued request events are
/// generic, and the callback will be called with the request.
class ClientRunner<T> {
  /// Construct a ClientRunner with provided [callback] method that accepts a [T].
  ClientRunner({required this.callback}) {
    _start();
  }

  int queueSize = 0;

  Future<void> _start() async {
    await for (final T event in _controller.stream) {
      try {
        await callback(event);
      } catch (_) {
        // Swallow callback errors so the runner loop is never torn down by an
        // unhandled exception. Individual callers should log their own errors.
      } finally {
        queueSize--;
      }
    }
  }

  final StreamController<T> _controller = StreamController<T>();

  /// Function that will be called with enqueued request of type [T], one at a time.
  final Future<void> Function(T) callback;

  /// Enqueue a new request of type [T].
  void enqueueRequest(T event) {
    queueSize++;
    _controller.add(event);
  }

  void close() {
    _controller.close();
  }
}
