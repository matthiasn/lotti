import 'dart:collection';

/// A simple Least Recently Used (LRU) cache backed by a [LinkedHashMap].
///
/// When the cache exceeds [maxSize], the least recently accessed entries are
/// evicted. Both reads and writes count as access. The [containsKey] method
/// does NOT promote entries to prevent accidental eviction changes when only
/// checking existence.
class LruCache<K, V> {
  LruCache(this.maxSize) : assert(maxSize > 0, 'maxSize must be positive');

  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  int get length => _map.length;

  bool containsKey(K key) => _map.containsKey(key);

  V? operator [](K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
    }
    return value;
  }

  /// Gets the value for [key], promoting it to most-recently-used.
  ///
  /// Unlike [operator []], this method correctly handles cached `null` values
  /// by returning a record indicating whether the key was present.
  ({bool found, V? value}) getEntry(K key) {
    if (!_map.containsKey(key)) {
      return (found: false, value: null);
    }
    final value = _map.remove(key);
    _map[key] = value as V;
    return (found: true, value: value);
  }

  void operator []=(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    _evict();
  }

  void remove(K key) => _map.remove(key);

  void removeWhere(bool Function(K key, V value) test) =>
      _map.removeWhere(test);

  void clear() => _map.clear();

  Iterable<K> get keys => _map.keys;

  Iterable<V> get values => _map.values;

  void _evict() {
    while (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }
}
