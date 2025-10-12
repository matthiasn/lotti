/// Common String extensions used across the app.
extension TruncateString on String {
  /// Returns this string truncated to [maxLength]. If the string exceeds
  /// [maxLength], it is shortened and suffixed with [ellipsis] (default '…').
  /// If [maxLength] is shorter than the ellipsis length, the result is the
  /// ellipsis itself.
  String truncate(int maxLength, [String ellipsis = '…']) {
    if (length <= maxLength) return this;
    if (maxLength <= ellipsis.length) return ellipsis;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}
