/// Provides locale-aware time information without requiring BuildContext.
///
/// Notes:
/// - Uses a small built-in mapping for common locales. If a locale is not
///   included, defaults to Monday (1), which matches ISO-8601.
class TimeLocaleService {
  static const Map<String, int> _firstDayOfWeekByLocale = {
    // Sunday-start locales
    'en_us': 0,
    'en-US': 0,
    // Monday-start locales (common in Europe)
    'en_gb': 1,
    'en-GB': 1,
    'de_de': 1,
    'de-DE': 1,
    'fr_fr': 1,
    'fr-FR': 1,
    'es_es': 1,
    'es-ES': 1,
  };

  /// Returns the locale's first day of week as an index 0–6 where Sunday=0.
  /// Defaults to Monday (1) if unknown.
  Future<int> firstDayOfWeekIndex({String? locale}) async {
    if (locale == null || locale.isEmpty) return 1;
    final normalized = locale.replaceAll('-', '_');
    final lower = normalized.toLowerCase();
    return _firstDayOfWeekByLocale[normalized] ??
        _firstDayOfWeekByLocale[lower] ??
        1;
  }
}
