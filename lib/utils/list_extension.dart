extension ListExtension<T> on List<T> {
  (List<T>, T?, List<T>?) partition(
    bool Function(T) predicate,
  ) {
    final pos = indexWhere(predicate);
    if (pos == -1) {
      return (this, null, null);
    }
    final length = this.length;
    final before = sublist(0, pos);
    final match = elementAt(pos);
    final after = length > pos + 1 ? sublist(pos + 1, length) : null;
    return (before, match, after);
  }
}
