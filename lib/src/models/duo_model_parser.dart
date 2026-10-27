/// Helpers for safely decoding values received from platform channels.
abstract final class DuoModelParser {
  /// Converts a native map with string keys into a typed map.
  static Map<String, Object?> map(Object? value, String name) {
    if (value is! Map<Object?, Object?>) {
      throw FormatException('Expected $name to be a map.');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key case final String key) result[key] = entry.value;
    }
    return result;
  }

  /// Reads a finite numeric value.
  static double number(Object? value, String name) {
    if (value is! num || !value.toDouble().isFinite) {
      throw FormatException('Expected $name to be a finite number.');
    }
    return value.toDouble();
  }

  /// Reads a nullable finite number.
  static double? optionalNumber(Object? value, String name) =>
      value == null ? null : number(value, name);

  /// Reads a boolean, or a supplied default when absent.
  static bool boolean(Object? value, String name, {bool? fallback}) {
    if (value == null && fallback != null) return fallback;
    if (value is bool) return value;
    throw FormatException('Expected $name to be a boolean.');
  }

  /// Reads an optional string.
  static String? optionalString(Object? value, String name) {
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Expected $name to be a string.');
  }

  /// Reads an ISO-8601 timestamp, defaulting to the current time if absent.
  static DateTime dateTime(Object? value, String name) {
    if (value == null) throw FormatException('Expected $name timestamp.');
    if (value is DateTime) return value;
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Expected $name to be an ISO-8601 timestamp.');
  }
}
